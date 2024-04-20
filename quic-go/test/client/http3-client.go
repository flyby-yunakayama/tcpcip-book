package main

import (
	"bufio"
	"crypto/tls"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"

	"os"

	"github.com/quic-go/quic-go"
	"github.com/quic-go/quic-go/http3"
	"github.com/quic-go/quic-go/internal/utils"
	"github.com/quic-go/quic-go/logging"
	"github.com/quic-go/quic-go/qlog"
)

func main() {

	var qconf quic.Config
	qconf.Tracer = qlog.NewTracer(func(_ logging.Perspective, connID []byte) io.WriteCloser {
		filename := fmt.Sprintf("client_%x.qlog", connID)
		f, err := os.Create(filename)
		if err != nil {
			log.Fatal(err)
		}
		log.Printf("Creating qlog file %s.\n", filename)
		return utils.NewBufferedWriteCloser(bufio.NewWriter(f), f)
	})

	w := os.Stdout // ←追加
	r := http3.RoundTripper{
		TLSClientConfig: &tls.Config{
			MinVersion:         tls.VersionTLS13,
			MaxVersion:         tls.VersionTLS13,
			KeyLogWriter:       w,
			InsecureSkipVerify: true,
		},
		QuicConfig: &qconf,
	}
	req, _ := http.NewRequest("GET", "https://localhost:18443/", nil)
	// req, _ := http.NewRequest("GET", "https://example.com", nil)

	resp, err := r.RoundTrip(req)
	if err != nil {
		log.Fatal(err)
	}

	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Print(string(body))
}
