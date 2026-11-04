/* Diagnostic preload: record only USP UDS I/O for one service without stopping its threads.
 * No libc is linked; dlsym and errno resolve from the guest's musl runtime.
 * Each record has the real syscall return and preserves the caller's errno.
 */
#ifndef USP_SOCKET_PREFIX
#define USP_SOCKET_PREFIX "/var/run/usp/"
#endif
#ifndef USP_TRACE_DIRECTORY
#define USP_TRACE_DIRECTORY "/run/usp-timing"
#endif
/* The outgoing handshake can carry a password. Do not retain writes until
 * the broker has responded on that descriptor. Reset the gate on FD reuse.
 */
static unsigned char received[4096];
typedef unsigned long size_t;
typedef long ssize_t;
extern void *dlsym(void *, const char *);
extern int *__errno_location(void);
static ssize_t (*real_read)(int, void *, size_t);
static ssize_t (*real_write)(int, const void *, size_t);
static int (*real_close)(int);
static int (*real_connect)(int, const void *, unsigned);
struct iovec { void *base; size_t len; };
struct msghdr {
    void *name; unsigned namelen; struct iovec *iov; size_t iovlen;
    void *control; size_t controllen; int flags;
};
static ssize_t (*real_recv)(int, void *, size_t, int);
static ssize_t (*real_send)(int, const void *, size_t, int);
static ssize_t (*real_recvmsg)(int, struct msghdr *, int);
static ssize_t (*real_sendmsg)(int, const struct msghdr *, int);
static long sc(long n, long a, long b, long c, long d, long e) {
    register long r10 __asm__("r10") = d;
    register long r8 __asm__("r8") = e;
    long r;
    __asm__ volatile("syscall" : "=a"(r) : "a"(n), "D"(a), "S"(b),
                     "d"(c), "r"(r10), "r"(r8) : "rcx", "r11", "memory");
    return r;
}
__attribute__((constructor)) static void init(void) {
    real_read = dlsym((void *)-1, "read");
    real_write = dlsym((void *)-1, "write");
    real_close = dlsym((void *)-1, "close");
    real_connect = dlsym((void *)-1, "connect");
    real_recv = dlsym((void *)-1, "recv");
    real_send = dlsym((void *)-1, "send");
    real_recvmsg = dlsym((void *)-1, "recvmsg");
    real_sendmsg = dlsym((void *)-1, "sendmsg");
}
static char *word(char *p, const char *s) { while (*s) *p++ = *s++; return p; }
static char *number(char *p, long n) {
    char b[24]; unsigned i=0; unsigned long v;
    if (n<0) { *p++='-'; v=(unsigned long)(-(n+1))+1; } else v=n;
    do { b[i++]=(char)('0'+v%10); v/=10; } while(v);
    while(i) *p++=b[--i];
    return p;
}
static int usp_socket(int fd) {
    struct { unsigned short family; char path[108]; } a={0};
    unsigned len=sizeof(a);
    if(sc(51,fd,(long)&a,(long)&len,0,0)<0 || a.family!=1) return 0;
    const char prefix[]=USP_SOCKET_PREFIX;
    unsigned i=0; while(prefix[i] && a.path[i]==prefix[i]) i++;
    if(!prefix[i]) return 1;
    len=sizeof(a);
    if(sc(52,fd,(long)&a,(long)&len,0,0)<0 || a.family!=1) return 0;
    i=0; while(prefix[i] && a.path[i]==prefix[i]) i++;
    return !prefix[i];
}
static void emit(const char *op, int fd, const void *data, size_t requested,
                 ssize_t result, int err) {
    if(!usp_socket(fd)) return;
    if(fd<0 || fd>=4096) return;
    if(op[0]=='r' && result>0) received[fd]=1;
    if((op[0]=='s' || op[0]=='w') && !received[fd]) return;
    char buf[34000], *p=buf;
    struct { long sec, nsec; } ts;
    struct { int pid; unsigned uid,gid; } peer={0,0,0};
    unsigned len=sizeof(peer);
    unsigned long stat[32]={0};
    sc(228,1,(long)&ts,0,0,0); /* monotonic time */
    sc(55,fd,1,17,(long)&peer,(long)&len);
    sc(5,fd,(long)stat,0,0,0);
    p=word(p,"sec="); p=number(p,ts.sec);
    p=word(p," ns="); p=number(p,ts.nsec);
    p=word(p," pid="); p=number(p,sc(39,0,0,0,0,0));
    p=word(p," tid="); p=number(p,sc(186,0,0,0,0,0));
    p=word(p," op="); p=word(p,op);
    p=word(p," fd="); p=number(p,fd);
    p=word(p," inode="); p=number(p,(long)stat[1]);
    p=word(p," peer="); p=number(p,peer.pid);
    p=word(p," requested="); p=number(p,(long)requested);
    p=word(p," result="); p=number(p,result);
    p=word(p," errno="); p=number(p,result<0?err:0);
    p=word(p," data=");
    size_t n=(result>0 && data)?(size_t)result:0;
    if(n>requested) n=requested;
    if(n>16384) n=16384;
    const unsigned char *b=data; const char hex[]="0123456789abcdef";
    for(size_t i=0;i<n;i++){*p++=hex[b[i]>>4];*p++=hex[b[i]&15];}
    *p++='\n';
    char path[96], *q=word(path,USP_TRACE_DIRECTORY "/socket-io-");
    q=number(q,sc(39,0,0,0,0,0)); q=word(q,".log"); *q=0;
    long out=sc(257,-100,(long)path,1|64|1024,0600,0);
    if(out>=0){sc(1,out,(long)buf,p-buf,0,0);sc(3,out,0,0,0,0);}
}
ssize_t read(int fd, void *b, size_t n) {
    ssize_t r=real_read(fd,b,n); int e=*__errno_location();
    emit("read",fd,b,n,r,e); *__errno_location()=e; return r;
}
ssize_t write(int fd, const void *b, size_t n) {
    ssize_t r=real_write(fd,b,n); int e=*__errno_location();
    emit("write",fd,b,n,r,e); *__errno_location()=e; return r;
}
int close(int fd) {
    int e=*__errno_location(); emit("close",fd,0,0,0,0);
    if(fd>=0 && fd<4096) received[fd]=0;
    *__errno_location()=e; return real_close(fd);
}
ssize_t recv(int fd, void *b, size_t n, int flags) {
    ssize_t r=real_recv(fd,b,n,flags); int e=*__errno_location();
    emit("recv",fd,b,n,r,e); *__errno_location()=e; return r;
}
ssize_t send(int fd, const void *b, size_t n, int flags) {
    ssize_t r=real_send(fd,b,n,flags); int e=*__errno_location();
    emit("send",fd,b,n,r,e); *__errno_location()=e; return r;
}
static void message(const char *op, int fd, const struct msghdr *m, ssize_t r, int e) {
    char data[16384]; size_t pos=0, total=0, remaining=r>0?(size_t)r:0;
    for(size_t i=0;i<m->iovlen;i++) {
        total+=m->iov[i].len;
        size_t n=m->iov[i].len;
        if(n>remaining) n=remaining;
        if(n>sizeof(data)-pos) n=sizeof(data)-pos;
        const char *src=m->iov[i].base;
        for(size_t j=0;j<n;j++) data[pos++]=src[j];
        remaining-=n;
    }
    emit(op,fd,data,total,r,e);
}
ssize_t recvmsg(int fd, struct msghdr *m, int flags) {
    ssize_t r=real_recvmsg(fd,m,flags); int e=*__errno_location();
    message("recvmsg",fd,m,r,e); *__errno_location()=e; return r;
}
ssize_t sendmsg(int fd, const struct msghdr *m, int flags) {
    ssize_t r=real_sendmsg(fd,m,flags); int e=*__errno_location();
    message("sendmsg",fd,m,r,e); *__errno_location()=e; return r;
}

int connect(int fd, const void *address, unsigned length) {
    int r=real_connect(fd,address,length), e=*__errno_location();
    if(fd>=0 && fd<4096) received[fd]=0;
    if(r==0) emit("connect",fd,0,0,r,e);
    *__errno_location()=e; return r;
}
