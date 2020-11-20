package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/lambda"
)

func handleRequest(ctx context.Context) (string, error) {
	return fmt.Sprintf(`Hello from ACK Lambda controller!`), nil
}

func main() {
	lambda.Start(handleRequest)
}
