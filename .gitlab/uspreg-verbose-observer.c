/* Diagnostic preload: record only USP UDS I/O for one service without stopping its threads.
 * No libc is linked; dlsym and errno resolve from the guest's musl runtime.
 * Each record has the real syscall return and preserves the caller's errno.
 */
#ifndef USP_SOCKET_PREFIX
#define USP_SOCKET_PREFIX "/var/run/usp/"
#endif
#ifndef USP_TRACE_DIRECTORY
#define USP_TRACE_DIRECTORY "/run/usp-verbose"
#endif
/* No socket payload is written. Only allowlisted protocol metadata leaves RAM. */
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
static int connecting_fd=-1;
static long connecting_tid;
static int usp_socket(int fd) {
    if(fd==connecting_fd && connecting_tid==sc(186,0,0,0,0,0)) return 1;
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
struct bytes { const unsigned char *p; size_t n; };
static unsigned long vint(struct bytes *b) {
    unsigned long v=0; unsigned shift=0;
    while(b->n && shift<63) {
        unsigned c=*b->p++; b->n--; v|=(unsigned long)(c&127)<<shift;
        if(!(c&128)) return v;
        shift+=7;
    }
    b->n=0; return 0;
}
/* Return one selected field, skipping all other fields without formatting them. */
static struct bytes field(struct bytes b, unsigned wanted, unsigned occurrence) {
    struct bytes empty={0,0};
    while(b.n) {
        unsigned tag=(unsigned)vint(&b); unsigned wire=tag&7;
        struct bytes value={b.p,0};
        if(wire==0) { const unsigned char *start=b.p; vint(&b); value.p=start; value.n=b.p-start; }
        else {
            size_t n=wire==2?vint(&b):(wire==5?4:(wire==1?8:b.n+1));
            if(n>b.n) return empty;
            value.p=b.p; value.n=n; b.p+=n; b.n-=n;
        }
        if((tag>>3)==wanted && occurrence--==0) return value;
    }
    return empty;
}
static unsigned be32(const unsigned char *p) {
    return ((unsigned)p[0]<<24)|((unsigned)p[1]<<16)|((unsigned)p[2]<<8)|p[3];
}
static char *hexfield(char *p, struct bytes b, size_t cap) {
    const char h[]="0123456789abcdef";
    if(b.n>cap) return word(p,"omitted-too-long");
    for(size_t i=0;i<b.n;i++) { *p++=h[b.p[i]>>4]; *p++=h[b.p[i]&15]; }
    return p;
}
/* Fixed bounded storage, no allocation and no callbacks into the program. */
struct stream { int fd; unsigned used[2], gap[2]; unsigned char data[2][32768]; };
static struct stream streams[16];
static volatile int busy;
static char *metadata(char *p, struct bytes frame, char *end) {
    while(frame.n>=5) {
        /* A REGISTER emits at most 16 bounded paths plus one bounded ID. */
        if(end-p<10000) return word(p," capture_gap=metadata_capacity");
        unsigned kind=frame.p[0], size=be32(frame.p+1);
        frame.p+=5; frame.n-=5;
        if(size>frame.n) return word(p," malformed_tlv=1");
        struct bytes value={frame.p,size}; frame.p+=size; frame.n-=size;
        if(kind==1) p=word(p," event=handshake_socket_io");
        if(kind!=3) continue;
        struct bytes context=field(value,7,0), message=field(context,2,0);
        struct bytes header=field(message,1,0), type=field(header,2,0);
        unsigned long t=vint(&type);
        p=word(p," msg_type="); p=number(p,t);
        if(t!=0 && t!=19 && t!=20) continue;
        p=word(p," msg_id_hex="); p=hexfield(p,field(header,1,0),128);
        struct bytes body=field(message,2,0);
        if(t==19) {
            struct bytes reg=field(field(body,1,0),10,0);
            for(unsigned i=0;i<16;i++) {
                struct bytes entry=field(reg,2,i); if(!entry.n) break;
                p=word(p," register_path_hex="); p=hexfield(p,field(entry,1,0),256);
            }
        }
        if(t==0) {
            struct bytes code=field(field(body,3,0),1,0);
            if(code.n==4) { p=word(p," error_code=");
                p=number(p,(unsigned long)code.p[0]|((unsigned long)code.p[1]<<8)|
                         ((unsigned long)code.p[2]<<16)|((unsigned long)code.p[3]<<24)); }
        }
        /* REGISTER_RESP details remain in the private broker protocol log. */
    }
    return p;
}
static void emit(const char *op, int fd, const void *data, size_t requested,
                 ssize_t result, int err) {
    if(!usp_socket(fd)) return;
    char buf[34000], *p=buf;
    struct { long sec, nsec; } ts={0,0};
    struct { int pid; unsigned uid,gid; } peer={0,0,0};
    unsigned len=sizeof(peer); unsigned long stat[32]={0};
    sc(228,1,(long)&ts,0,0,0);
    sc(55,fd,1,17,(long)&peer,(long)&len); sc(5,fd,(long)stat,0,0,0);
    p=word(p,"sec="); p=number(p,ts.sec); p=word(p," ns="); p=number(p,ts.nsec);
    p=word(p," pid="); p=number(p,sc(39,0,0,0,0,0));
    p=word(p," tid="); p=number(p,sc(186,0,0,0,0,0));
    p=word(p," op="); p=word(p,op); p=word(p," fd="); p=number(p,fd);
    p=word(p," inode="); p=number(p,(long)stat[1]);
    p=word(p," peer="); p=number(p,peer.pid);
    p=word(p," requested="); p=number(p,(long)requested);
    p=word(p," result="); p=number(p,result);
    p=word(p," errno="); p=number(p,result<0?err:0);
    if(__sync_lock_test_and_set(&busy,1)) p=word(p," capture_gap=concurrent");
    else {
        struct stream *s=0;
        for(unsigned i=0;i<16;i++) if(streams[i].fd==fd+1) {s=&streams[i];break;}
        if(!s) for(unsigned i=0;i<16;i++) if(!streams[i].fd) {s=&streams[i];s->fd=fd+1;break;}
        if(!s) p=word(p," capture_gap=socket_capacity");
        else if(op[0]=='c') { s->used[0]=s->used[1]=s->gap[0]=s->gap[1]=0; if(op[1]=='l') s->fd=0; }
        else if(result>0 && data) {
            unsigned d=op[0]=='r'?0:1; size_t n=(size_t)result;
            if(n>requested || n>16384 || n>sizeof(s->data[d])-s->used[d]) s->gap[d]=1;
            if(s->gap[d]) p=word(p," capture_gap=buffer");
            else {
                for(size_t i=0;i<n;i++) s->data[d][s->used[d]++]=((const unsigned char *)data)[i];
                while(s->used[d]>=8) {
                    unsigned char *b=s->data[d]; unsigned size=be32(b+4);
                    if(b[0]!='_' || b[1]!='U' || b[2]!='S' || b[3]!='P' || size>32760) {
                        s->gap[d]=1; p=word(p," capture_gap=framing"); break;
                    }
                    if(s->used[d]<size+8) break;
                    p=metadata(p,(struct bytes){b+8,size},buf+sizeof(buf));
                    s->used[d]-=size+8;
                    for(unsigned i=0;i<s->used[d];i++) b[i]=b[i+size+8];
                    /* Bound one log line even for coalesced frames. */
                    if(p-buf>18000) {p=word(p," capture_gap=line_capacity");s->gap[d]=1;break;}
                }
            }
        }
        __sync_lock_release(&busy);
    }
    *p++='\n'; char path[96], *q=word(path,USP_TRACE_DIRECTORY "/socket-io-");
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
    /* getpeername cannot identify a failed attempt: check its supplied address. */
    struct address { unsigned short family; char path[108]; };
    const struct address *a=address; const char prefix[]=USP_SOCKET_PREFIX;
    unsigned i=0;
    if(length>=2 && a && a->family==1) {
        while(prefix[i] && i+2<length && a->path[i]==prefix[i]) i++;
        if(!prefix[i]) {
            /* emit() accepts unconnected USP sockets using the temporary gate. */
            connecting_tid=sc(186,0,0,0,0,0); connecting_fd=fd; emit("connect",fd,0,0,r,e); connecting_fd=-1;
        }
    }
    *__errno_location()=e; return r;
}
