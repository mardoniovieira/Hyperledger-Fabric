
package main

/* Imports
 * 4 utility libraries for formatting, handling bytes, reading and writing JSON, and string manipulation
 * 1 specific Hyperledger Fabric specific libraries for Smart Contracts
 */
import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Define the Smart Contract structure
type SmartContract struct {
	contractapi.Contract
}

type Transaction struct {
	Tag				string 	`json:"tag"`
	Date			string 	`json:"date"`
	KeyPubPacient	string 	`json:"keyPubPacient"`
	KeyPubDoctor	string 	`json:"keyPubDoctor"`
}

// QueryResult structure used for handling result of query
type QueryResult struct {
	Key    string `json:"Key"`
	Record *Transaction
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	transactions := []Transaction{
		Transaction{Tag: "tagA", Date: "01-03-2020", KeyPubPacient: "chavePublicaPaciente1", KeyPubDoctor: "chavePublicaDoutor1"},
		Transaction{Tag: "tagB", Date: "03-03-2020", KeyPubPacient: "chavePublicaPaciente2", KeyPubDoctor: "chavePublicaDoutor2"},
		Transaction{Tag: "tagA", Date: "01-04-2020", KeyPubPacient: "chavePublicaPaciente2", KeyPubDoctor: "chavePublicaDoutor1"},
		Transaction{Tag: "tagA", Date: "01-05-2020", KeyPubPacient: "chavePublicaPaciente1", KeyPubDoctor: "chavePublicaDoutor3"},
	}

	for i, transaction := range transactions {
		transactionAsBytes, _ := json.Marshal(transaction)
		err := ctx.GetStub().PutState("Transaction"+strconv.Itoa(i), transactionAsBytes)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %s", err.Error())
		}
	}

	return nil
}

func (s *SmartContract) CreateTransaction(ctx contractapi.TransactionContextInterface, transactionNumber string, tag string, keyPubPacient string, keyPubDoctor string) error {
	
	currentTime := time.Now()

	transaction := Transaction {
		Tag:   tag,
		Date:  currentTime.Format("01-02-2006"),
		KeyPubPacient: keyPubPacient,
		KeyPubDoctor:  keyPubDoctor,
	}

	transactionAsBytes, _ := json.Marshal(transaction)

	return ctx.GetStub().PutState(transactionNumber, transactionAsBytes)
}

func (s *SmartContract) QueryTransaction(ctx contractapi.TransactionContextInterface, transactionNumber string) (*Transaction, error) {
	transactionAsBytes, err := ctx.GetStub().GetState(transactionNumber)

	if err != nil {
		return nil, fmt.Errorf("Failed to read from world state. %s", err.Error())
	}

	if transactionAsBytes == nil {
		return nil, fmt.Errorf("%s does not exist", transactionNumber)
	}

	transaction := new(Transaction)
	_ = json.Unmarshal(transactionAsBytes, transaction)

	return transaction, nil
}

func (s *SmartContract) QueryAllTransactions(ctx contractapi.TransactionContextInterface) ([]QueryResult, error) {
	startKey := ""
	endKey := ""

	resultsIterator, err := ctx.GetStub().GetStateByRange(startKey, endKey)

	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	results := []QueryResult{}

	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()

		if err != nil {
			return nil, err
		}

		transaction := new(Transaction)
		_ = json.Unmarshal(queryResponse.Value, transaction)

		queryResult := QueryResult{Key: queryResponse.Key, Record: transaction}
		results = append(results, queryResult)
	}

	return results, nil
}


func main() {

	chaincode, err := contractapi.NewChaincode(new(SmartContract))

	if err != nil {
		fmt.Printf("Error create health chaincode: %s", err.Error())
		return
	}

	if err := chaincode.Start(); err != nil {
		fmt.Printf("Error starting health chaincode: %s", err.Error())
	}
}

