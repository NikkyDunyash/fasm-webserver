format ELF64 executable

SYS_WRITE equ 1
SYS_CLOSE equ 3
SYS_SOCKET equ 41
SYS_ACCEPT equ 43
SYS_BIND equ 49
SYS_LISTEN equ 50
SYS_EXIT equ 60

STDIN equ 0
STDOUT equ 1
STDERR equ 2

AF_INET equ 2
SOCK_STREAM equ 1
IPPROTO_IP equ 0

PORT equ 36895  ;; inverted bytewise 8080
INADDR_ANY equ 0 ;; socket is bound to all network interfaces on host
MAX_CONNECTIONS equ 5


struc servaddr_in
{
	.sin_family dw 0
	.sin_port dw 0
	.sin_addr dd 0
	.sin_zero dq 0
	.size = $ - .sin_family
}

macro syscalln nr, arg0, arg1, arg2, arg3, arg4, arg5
{
	mov rax, nr
	mov rdi, arg0
	if ~(arg1 eq)
		mov rsi, arg1
	end if
	if ~(arg2 eq)
		mov rdx, arg2
	end if
	if ~(arg3 eq)
		mov r10, arg3
	end if
	if ~(arg4 eq)
		mov r8, arg4
	end if
	if ~(arg5 eq)
		mov r9, arg5
	end if
	syscall
}

;; ssize_t write(int fd, const void buf[.count], size_t count);
macro write fd, buf, count
{
	syscalln SYS_WRITE, fd, buf, count
}

;; int socket(int domain, int type, int protocol);
macro socket domain, type, protocol
{
	syscalln SYS_SOCKET, domain, type, protocol
}

;; int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
macro bind sockfd, addr, addrlen
{
	syscalln SYS_BIND, sockfd, addr, addrlen
}

;; int listen(int sockfd, int backlog);
macro listen sockfd, backlog
{
	syscalln SYS_LISTEN, sockfd, backlog
}

;; int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
macro accept sockfd, addr, addrlen
{
	syscalln SYS_ACCEPT, sockfd, addr, addrlen
}
;; int close(int fd);
macro close fd
{
	syscalln SYS_CLOSE, fd
}
;; void exit(int status);
macro exit status
{
	mov rax, SYS_EXIT
	mov rdi, status
	syscall
}

segment executable
entry main
main:

	write STDOUT, start_msg, start_msg_len

	write STDOUT, socket_msg, socket_msg_len
	socket AF_INET, SOCK_STREAM, IPPROTO_IP
	cmp rax, 0
	jl error
	mov qword [sockfd], rax

	write STDOUT, bind_msg, bind_msg_len
	mov [servaddr.sin_family], AF_INET
	mov [servaddr.sin_port], PORT
	mov [servaddr.sin_addr], INADDR_ANY
	bind [sockfd], servaddr.sin_family, servaddr.size
	cmp rax, 0
	jl error

	write STDOUT, listen_msg, listen_msg_len
	listen [sockfd], MAX_CONNECTIONS
	cmp rax, 0
	jl error


	write STDOUT, accept_msg, accept_msg_len

man_reqs:

	accept [sockfd], cliaddr.sin_family, cliaddr_size
	cmp rax, 0
	jl error
	mov qword [connfd], rax
	write [connfd], resp_head, resp_head_len
	write [connfd], resp_body, resp_body_len
	close [connfd]
	jmp man_reqs

	write STDOUT, ok_msg, ok_msg_len
	close [sockfd]
	exit 0

error:

	write STDERR, error_msg, error_msg_len
	close [connfd]
	close [sockfd]
	exit 1

segment readable writeable

	sockfd dq -1
	connfd dq -1
	servaddr servaddr_in
	cliaddr servaddr_in
	cliaddr_size dq cliaddr.size ; because we need *addrlen in accept

	start_msg db "INFO: Starting a web server!", 10
	start_msg_len = $-start_msg
	socket_msg db "INFO: Creating a socket...", 10
	socket_msg_len = $-socket_msg
	bind_msg db "INFO: Binding the socket...", 10
	bind_msg_len = $-bind_msg
	listen_msg db "INFO: Listening to the socket...", 10
	listen_msg_len = $-listen_msg
	accept_msg db "INFO: Waiting for clients' connections...", 10
	accept_msg_len = $-accept_msg
	resp_head db "HTTP/1.1 404 Go fuck urself.",  13, 10
			  db "Connection: close", 13, 10
			  db  13, 10
	resp_head_len = $-resp_head
	resp_body file "resp_body.html"
	resp_body_len = $-resp_body
	ok_msg db "INFO: Ok!", 10
	ok_msg_len = $-ok_msg
	error_msg db "ERROR!", 10
	error_msg_len = $-error_msg
