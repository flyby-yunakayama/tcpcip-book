package main

import (
	"bytes"
	"context"
	"crypto/rand"
	_ "embed"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/quic-go/quic-go/http3"

	"github.com/quic-go/webtransport-go"
)

var data []byte

func init() {
	data = make([]byte, 1<<2)
	rand.Read(data)
}

func main() {
	wmux := http.NewServeMux()
	s := webtransport.Server{
		H3: http3.Server{
			Addr:    "localhost:12345",
			Handler: wmux,
		},
		CheckOrigin: func(r *http.Request) bool { return true },
	}
	defer s.Close()

	wmux.HandleFunc("/unidirectional", func(w http.ResponseWriter, r *http.Request) {
		conn, err := s.Upgrade(w, r)
		if err != nil {
			log.Printf("upgrading failed: %s", err)
			w.WriteHeader(500)
			return
		}
		runUnidirectionalTest(conn)
	})

	err := s.ListenAndServeTLS("certificate.pem", "certificate.key")
	if err != nil {
		log.Fatal(err)
	}
}

func runUnidirectionalTest(sess *webtransport.Session) {
	for i := 0; i < 5; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		str, err := sess.AcceptUniStream(ctx)
		if err != nil {
			log.Fatalf("failed to accept unidirectional stream: %v", err)
		}
		rvcd, err := io.ReadAll(str)
		if err != nil {
			log.Fatalf("failed to read all data: %v", err)
		}
		if !bytes.Equal(rvcd, data) {
			log.Fatal("data doesn't match")
		}
	}
	select {
	case <-sess.Context().Done():
		fmt.Println("done")
	case <-time.After(5 * time.Second):
		log.Fatal("timed out waiting for the session to be closed")
	}
}
