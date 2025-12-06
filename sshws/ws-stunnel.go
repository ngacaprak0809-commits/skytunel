package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"time"
)

const (
	BUFLEN       = 4096 * 4
	TIMEOUT      = 60 * time.Second
	DEFAULT_HOST = "127.0.0.1:22"
)

// Kalau mau pakai password, isi di sini
const PASS = ""

// HTTP response untuk upgrade/tunnel
var RESPONSE = []byte("HTTP/1.1 101 Switching Protocols\r\nContent-Length: 104857600000\r\n\r\n")

func main() {
	listenAddr := flag.String("b", "127.0.0.1", "bind address")
	listenPort := flag.Int("p", 700, "port")
	flag.Parse()

	addr := fmt.Sprintf("%s:%d", *listenAddr, *listenPort)

	ln, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("Gagal listen di %s: %v", addr, err)
	}
	defer ln.Close()

	log.Println(":-------GoPythonProxy-------:")
	log.Printf("Listening addr: %s\n", *listenAddr)
	log.Printf("Listening port: %d\n", *listenPort)
	log.Println(":---------------------------:")

	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Printf("Error accept: %v", err)
			continue
		}
		go handleConnection(conn)
	}
}

func handleConnection(client net.Conn) {
	defer client.Close()
	remoteAddr := client.RemoteAddr().String()
	logPrefix := fmt.Sprintf("Connection: %s", remoteAddr)

	// batas waktu baca pertama (request header)
	_ = client.SetReadDeadline(time.Now().Add(2 * time.Second))

	buf := make([]byte, BUFLEN)
	n, err := client.Read(buf)
	if err != nil {
		if !isTimeout(err) {
			log.Printf("%s - error read initial: %v", logPrefix, err)
		}
		return
	}
	// setelah baca awal, hapus deadline
	_ = client.SetReadDeadline(time.Time{})

	reqStr := string(buf[:n])

	hostPort := findHeader(reqStr, "X-Real-Host")
	if hostPort == "" {
		hostPort = DEFAULT_HOST
	}

	split := findHeader(reqStr, "X-Split")
	if split != "" {
		// buang buffer tambahan
		_, _ = client.Read(buf)
	}

	if hostPort == "" {
		log.Println("- No X-Real-Host!")
		client.Write([]byte("HTTP/1.1 400 NoXRealHost!\r\n\r\n"))
		return
	}

	passwd := findHeader(reqStr, "X-Pass")

	// Logic password & security
	if PASS != "" && passwd == PASS {
		// ok
	} else if PASS != "" && passwd != PASS {
		client.Write([]byte("HTTP/1.1 400 WrongPass!\r\n\r\n"))
		return
	} else if !strings.HasPrefix(hostPort, "127.0.0.1") && !strings.HasPrefix(hostPort, "localhost") {
		client.Write([]byte("HTTP/1.1 403 Forbidden!\r\n\r\n"))
		return
	}

	log.Printf("%s - CONNECT %s", logPrefix, hostPort)

	target, err := connectTarget(hostPort)
	if err != nil {
		log.Printf("%s - error connect target: %v", logPrefix, err)
		client.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		return
	}
	defer target.Close()

	// kirim response upgrade
	if _, err := client.Write(RESPONSE); err != nil {
		log.Printf("%s - error send RESPONSE: %v", logPrefix, err)
		return
	}

	// Setelah tunnel terbentuk, bikin deadline umum
	_ = client.SetDeadline(time.Now().Add(TIMEOUT))
	_ = target.SetDeadline(time.Now().Add(TIMEOUT))

	// Tunnel dua arah
	pipe(client, target, logPrefix)
}

func findHeader(data, header string) string {
	// mirip versi Python: cari "Header: value\r\n"
	search := header + ": "
	idx := strings.Index(data, search)
	if idx == -1 {
		return ""
	}
	start := idx + len(search)
	end := strings.Index(data[start:], "\r\n")
	if end == -1 {
		return ""
	}
	return data[start : start+end]
}

func connectTarget(hostPort string) (net.Conn, error) {
	// kalau tanpa :port, default 443
	if !strings.Contains(hostPort, ":") {
		hostPort = hostPort + ":443"
	}
	return net.Dial("tcp", hostPort)
}

func pipe(a, b net.Conn, logPrefix string) {
	done := make(chan struct{}, 2)

	// a -> b
	go func() {
		_, err := io.Copy(b, a)
		if err != nil && !isTimeout(err) {
			log.Printf("%s - error copy a->b: %v", logPrefix, err)
		}
		done <- struct{}{}
	}()

	// b -> a
	go func() {
		_, err := io.Copy(a, b)
		if err != nil && !isTimeout(err) {
			log.Printf("%s - error copy b->a: %v", logPrefix, err)
		}
		done <- struct{}{}
	}()

	// tunggu salah satu selesai
	<-done
}

func isTimeout(err error) bool {
	nerr, ok := err.(net.Error)
	return ok && nerr.Timeout()
}