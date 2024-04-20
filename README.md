# tcpcip-book
TCP/IP技術入門のサポートページです。

![書影](images/top.png)



# quic-go

8章「8.1. Go言語によるQUICの実装」に記載の、quic-go利用に関する解説です。
本リポジトリにある「quic-go」(./quic-go)をダウンロードすると、以下のような構成になっています。

```
quic-go
├── test
│   ├── client
│   │   └ http3-client.go
│   └── server
│       └ http3-server.go
├── ...
```

以下のコマンドにより、[サーバ側コード](./quic-go/test/http3-server.go)を実行し、サーバのプロセスを動かします。

```
% go run server/http3-server.go
```

以下のコマンドで、[クライアント側コード](./quic-go/test/http3-client.go)を実行します。

```
% go run client/http3-client.go
hello world!
```

このように、"hello world!"メッセージを取得できれば成功です。


# webtransport-go

8章「8.3. WebTransportによる通信」に記載の、WebTransport利用に関する解説です。
本リポジトリにある「webtransport-go」(./webtransport-go)をダウンロードすると、以下のような構成になっています。

```
webtransport-go
├── interop
│   ├── index.html
│   ├── interop.py
│   └── main.go
├── ...
```

以下のコマンドで、サーバを起動します。

```
go run main.go
```

Webブラウザを起動し、localhost:8080/webtransportからサーバへアクセスします。
Chromeを起動すると、図のような画面が表示されます。
データの送信方法を選択できるようになっています。
アクセス先URLはデフォルトで入力されており、このときのアクセス先は、先ほど用意したローカルサーバです。

![Chromeを起動した際のスクリーンショット](images/08_15-chrome_initial.png)



