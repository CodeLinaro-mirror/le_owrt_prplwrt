"""Local protocol fixture. No host tools, mounts, credentials or real daemon."""
import json
from pathlib import Path
import shutil
import socket
import threading

class Broker:
    def __init__(self, root, path):
        self.root=root;self.path=path;self.requests=[];self.failure=None;self.bad_attach=False;self.missing_tree=False
        self.server=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
        self.server.bind(str(path));self.server.listen();self.server.settimeout(.1)
        self.stop=threading.Event();self.thread=threading.Thread(target=self.serve,daemon=True);self.thread.start()
    def close(self):
        self.stop.set();self.thread.join(2);self.server.close();self.path.unlink(missing_ok=True)
    def copy(self,source,destination):
        destination.mkdir(parents=True,exist_ok=True)
        for p in source.rglob('*'):
            if p.is_file() and not p.is_symlink() and not p.name.endswith(('.dl','.tmp','.hash')):
                target=destination/p.relative_to(source)
                if not target.exists():target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
    def handle(self,line):
        args=line.split();self.requests.append(args)
        if self.failure==args[0]:return 'ERR injected '+args[0]
        if args[0]=='ATTACH':
            _,key,slot,clean,digest=args
            active=self.root/f'slots/{slot}/prplos';owner=active.parent/'.owner';pool=self.root/'trees'/key
            if owner.exists() or active.exists():return 'ERR slot occupied'
            meta=self.root/'meta'/f'{key}.json'
            state=json.loads(meta.read_text()) if meta.exists() else {'incomplete':True}
            cold=clean=='1' or state['incomplete']
            reused=pool.exists() and not cold
            if pool.exists() and cold:shutil.rmtree(pool)
            pool.mkdir(parents=True,exist_ok=True);owner.write_text(key)
            pool.rename(active);self.copy(self.root/'dl',self.root/'dl-slots'/slot)
            if self.missing_tree:shutil.rmtree(active)
            return 'OK malformed' if self.bad_attach else f'OK reused={int(reused)} parent_sha=- state={"warm" if reused else "cold"}'
        if args[0]=='PUBLISH-DL':
            self.copy(self.root/'dl-slots'/args[1],self.root/'dl');return 'OK'
        if args[0]=='DETACH':
            _,slot,status,interrupted=args
            active=self.root/f'slots/{slot}/prplos';owner=active.parent/'.owner'
            if not owner.exists():return 'OK'
            key=owner.read_text();pool=self.root/'trees'/key
            if pool.exists():return 'ERR destination occupied'
            if active.exists():active.rename(pool)
            (self.root/'meta'/f'{key}.json').write_text(json.dumps({'incomplete':status!='0' and interrupted=='0','interrupted':interrupted=='1'}))
            owner.unlink();return 'OK'
        return 'ERR unknown request'
    def serve(self):
        while not self.stop.is_set():
            try:conn,_=self.server.accept()
            except socket.timeout:continue
            with conn:
                try:
                    line=conn.makefile('rb').readline(4096).decode()
                    conn.sendall((self.handle(line)+'\n').encode())
                except Exception as exc:
                    try:conn.sendall(('ERR fixture '+str(exc)+'\n').encode())
                    except OSError:pass
