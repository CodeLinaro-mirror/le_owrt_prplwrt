/* Read-only x86-64 Linux socket peer check for guests without ss/UNIX_DIAG.
 * pidfd_getfd duplicates the service's descriptor, without touching its data.
 * /proc/net/unix supplies state/inode; SO_PEERCRED proves the broker peer PID.
 * No libc dependency: compile with -nostdlib -static -no-pie -fno-builtin.
 */
static long call(long n, long a, long b, long c, long d, long e) {
    register long r10 __asm__("r10") = d;
    register long r8 __asm__("r8") = e;
    long result;
    __asm__ volatile("syscall" : "=a"(result)
                     : "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10), "r"(r8)
                     : "rcx", "r11", "memory");
    return result;
}
static long number(const char *s) {
    long n = 0;
    if (!*s) return -1;
    for (; *s; s++) {
        if (*s < '0' || *s > '9') return -1;
        n = n * 10 + *s - '0';
    }
    return n;
}
static void message(const char *s) {
    long n = 0;
    while (s[n]) n++;
    call(1, 2, (long)s, n, 0, 0);
}
int peer_main(long argc, char **argv) {
    if (argc != 4) return 2;
    long pid = number(argv[1]), fd = number(argv[2]), broker = number(argv[3]);
    if (pid <= 0 || fd < 0 || broker <= 0) return 2;
    long pfd = call(434, pid, 0, 0, 0, 0); /* pidfd_open */
    if (pfd < 0) { message("pidfd_open unavailable\n"); return 2; }
    long copy = call(438, pfd, fd, 0, 0, 0); /* pidfd_getfd */
    call(3, pfd, 0, 0, 0, 0);
    if (copy < 0) { message("pidfd_getfd unavailable or denied\n"); return 2; }
    struct { int pid; unsigned int uid, gid; } cred;
    unsigned int length = sizeof(cred);
    long result = call(55, copy, 1, 17, (long)&cred, (long)&length); /* SO_PEERCRED */
    call(3, copy, 0, 0, 0, 0);
    if (result == 0 && length == sizeof(cred) && cred.pid == broker) {
        const char token[] = "peer-confirmed\n";
        call(1, 1, (long)token, sizeof(token) - 1, 0, 0);
        return 0;
    }
    return 1;
}
__asm__(".global _start\n"
        "_start:\n"
        "mov (%rsp), %rdi\n"
        "lea 8(%rsp), %rsi\n"
        "and $-16, %rsp\n"
        "call peer_main\n"
        "mov %eax, %edi\n"
        "mov $60, %eax\n"
        "syscall\n");
