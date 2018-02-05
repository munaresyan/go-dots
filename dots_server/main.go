package main

import (
	"flag"
	"os"
	"time"

	log "github.com/sirupsen/logrus"
	common "github.com/nttdots/go-dots/dots_common"
	dots_config "github.com/nttdots/go-dots/dots_server/config"
	"github.com/nttdots/go-dots/libcoap"
)

var (
	configFile        string
	defaultConfigFile = "dots_server.yaml"
)

func init() {
	flag.StringVar(&configFile, "config", defaultConfigFile, "config yaml file")
}

func main() {
	flag.Parse()
	common.SetUpLogger()

	_, err := dots_config.LoadServerConfig(configFile)
	if err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
	config := dots_config.GetServerSystemConfig()

	libcoap.Startup()
	defer libcoap.Cleanup()

	dtlsParam := libcoap.DtlsParam{
		&config.SecureFile.CertFile,
		nil,
		&config.SecureFile.ServerCertFile,
		&config.SecureFile.ServerKeyFile,
	}

	signalCtx, err := listenSignal(config.Network.BindAddress, uint16(config.Network.SignalChannelPort), &dtlsParam)
	if err != nil {
		log.Error(err)
		os.Exit(1)
	}
	defer signalCtx.FreeContext()

	dataCtx, err := listenData(config.Network.BindAddress, uint16(config.Network.DataChannelPort), &dtlsParam)
	if err != nil {
		log.Error(err)
		os.Exit(1)
	}
	defer dataCtx.FreeContext()

	for {
		signalCtx.RunOnce(time.Duration(100) * time.Millisecond)
		dataCtx.RunOnce(time.Duration(100) * time.Millisecond)
	}
}
