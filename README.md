# sbuild on BuildKit (Docker Bake)

BuildKitとDocker Bakeを使ったDebianパッケージビルダー

## 使用方法

### Dockerfileのみ使う場合

Debianパッケージのソース、`debian`ディレクトリの親ディレクトリで以下のコマンドを実行すると、
`noble`-`amd64`向けにパッケージをビルドすることができます。
`security.insecure`の許可が必要です。
ビルド引数は以下の通りです。

- `DIST`: ターゲットバージョン
- `ARCH`: ターゲットアーキテクチャ
- `APT_PROXY`: apt-cacherなどのプロキシサーバーを使う場合、`Acquire::http::Proxy "http://proxy.example.com:3142";`のように指定します
- `CACHEBUST`: ビルド部分でキャッシュを使用しないようにするため、日時など毎回変わる値を渡してください

```sh
docker buildx build -f /path/to/sbuild-on-buildkit/Dockerfile --target deploy --allow=security.insecure --build-arg DIST=noble --build-arg ARCH=amd64 --build-arg "CACHEBUST=$(date)" -o type=local,dest=build .
```

### Docker Bakeを使う場合

Debianパッケージのソース、`debian`ディレクトリの親ディレクトリで以下のコマンドを実行すると、
`build`ディレクトリにUbuntuの各バージョン・アーキテクチャのパッケージがビルドされます。

```sh
make -f /path/to/sbuild-on-buildkit/Makefile
```

そのまま使うと、`trusty`～`noble`のLTSバージョン、`amd64`と`arm64`をターゲットにしてビルドします。
不要なものは削ってください。
