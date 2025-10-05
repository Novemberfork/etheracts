package contracts

import (
	"fmt"
	"math/big"

	"github.com/NethermindEth/juno/core/felt"
	"github.com/NethermindEth/starknet.go/utils"
	"github.com/sirupsen/logrus"

	"github.com/NovemberFork/etheracts/integration/pkg/config"
	"github.com/NovemberFork/etheracts/integration/pkg/deploy"
)

// EthrxDeployer handles Ethrx contract deployment
type EthrxDeployer struct {
	deployer *deploy.Deployer
	config   *config.EthrxConfig
	logger   *logrus.Logger
}

// NewEthrxDeployer creates a new Ethrx deployer
func NewEthrxDeployer(deployer *deploy.Deployer, config *config.EthrxConfig, logger *logrus.Logger) *EthrxDeployer {
	return &EthrxDeployer{
		deployer: deployer,
		config:   config,
		logger:   logger,
	}
}

// Deploy deploys the Ethrx contract
func (e *EthrxDeployer) Deploy() (*deploy.DeploymentResult, error) {
	e.logger.Info("🚀 Deploying Ethrx Contract")
	e.logger.Info("=====================================")

	// Build constructor arguments
	constructorArgs, err := e.buildConstructorArgs()
	if err != nil {
		return nil, fmt.Errorf("failed to build constructor arguments: %w", err)
	}

	// Create contract info
	contractInfo := deploy.ContractInfo{
		Name:       "Ethrx",
		SierraPath: e.config.SierraPath,
		CasmPath:   e.config.CasmPath,
		Constructor: deploy.ConstructorArgs{
			Args: constructorArgs,
		},
	}

	// Deploy the contract
	result, err := e.deployer.DeployContract(contractInfo)
	if err != nil {
		return nil, fmt.Errorf("deployment failed: %w", err)
	}

	e.logger.Info("🎉 Ethrx deployment completed successfully!")
	e.logger.Info("📋 Summary:")
	e.logger.Infof("   Class Hash: %s", result.ClassHash)
	e.logger.Infof("   Deployed Address: %s", result.DeployedAddress)
	e.logger.Infof("   Transaction Hash: %s", result.TransactionHash)
	e.logger.Infof("   Deployment Time: %s", result.DeploymentTime.Format("2006-01-02 15:04:05"))

	return result, nil
}

// GetContractName returns the contract name
func (e *EthrxDeployer) GetContractName() string {
	return "Ethrx"
}

// ValidateConfig validates the Ethrx configuration
func (e *EthrxDeployer) ValidateConfig() error {
	if e.config.Owner == "" {
		return fmt.Errorf("owner address is required")
	}
	if e.config.Name == "" {
		return fmt.Errorf("contract name is required")
	}
	if e.config.Symbol == "" {
		return fmt.Errorf("contract symbol is required")
	}
	if e.config.SierraPath == "" {
		return fmt.Errorf("sierra path is required")
	}
	if e.config.CasmPath == "" {
		return fmt.Errorf("casm path is required")
	}
	return nil
}

// buildConstructorArgs builds the constructor arguments for Ethrx contract
func (e *EthrxDeployer) buildConstructorArgs() ([]*felt.Felt, error) {
	e.logger.Debug("🔧 Building constructor arguments...")

	var calldata []*felt.Felt

	// Convert owner address
	owner, err := utils.HexToFelt(e.config.Owner)
	if err != nil {
		return nil, fmt.Errorf("invalid owner address: %w", err)
	}
	calldata = append(calldata, owner)

	// Convert name to ByteArray (Cairo ByteArray structure)
	nameFelts, err := stringToByteArray(e.config.Name)
	if err != nil {
		return nil, fmt.Errorf("invalid name: %w", err)
	}
	calldata = append(calldata, nameFelts...)

	// Convert symbol to ByteArray (Cairo ByteArray structure)
	symbolFelts, err := stringToByteArray(e.config.Symbol)
	if err != nil {
		return nil, fmt.Errorf("invalid symbol: %w", err)
	}
	calldata = append(calldata, symbolFelts...)

	// Convert base URI to ByteArray (Cairo ByteArray structure)
	baseURIFelts, err := stringToByteArray(e.config.BaseURI)
	if err != nil {
		return nil, fmt.Errorf("invalid base URI: %w", err)
	}
	calldata = append(calldata, baseURIFelts...)

	// Convert mint token address
	mintToken, err := utils.HexToFelt(e.config.MintToken)
	if err != nil {
		return nil, fmt.Errorf("invalid mint token address: %w", err)
	}
	calldata = append(calldata, mintToken)

	// Convert mint price (u256) - split into low and high 128 bits
	mintPriceBig, ok := new(big.Int).SetString(e.config.MintPrice, 10)
	if !ok {
		return nil, fmt.Errorf("invalid mint price: %s", e.config.MintPrice)
	}
	mintPriceLow, mintPriceHigh := splitU256(mintPriceBig)
	calldata = append(calldata, mintPriceLow, mintPriceHigh)

	// Convert max supply (u256) - split into low and high 128 bits
	maxSupplyBig, ok := new(big.Int).SetString(e.config.MaxSupply, 10)
	if !ok {
		return nil, fmt.Errorf("invalid max supply: %s", e.config.MaxSupply)
	}
	maxSupplyLow, maxSupplyHigh := splitU256(maxSupplyBig)
	calldata = append(calldata, maxSupplyLow, maxSupplyHigh)

	e.logger.Debugf("✅ Constructor arguments built: %d arguments", len(calldata))
	e.logger.Debugf("   Owner: %s", e.config.Owner)
	e.logger.Debugf("   Name: %s", e.config.Name)
	e.logger.Debugf("   Symbol: %s", e.config.Symbol)
	e.logger.Debugf("   Base URI: %s", e.config.BaseURI)
	e.logger.Debugf("   Mint Token: %s", e.config.MintToken)
	e.logger.Debugf("   Mint Price: %s", e.config.MintPrice)
	e.logger.Debugf("   Max Supply: %s", e.config.MaxSupply)

	// Log the actual felt array for debugging
	e.logger.Debugf("🔍 Constructor calldata (felt array):")
	for i, felt := range calldata {
		e.logger.Debugf("   [%d]: %s", i, felt.String())
	}

	return calldata, nil
}

// splitU256 splits a u256 into low and high 128-bit parts
func splitU256(value *big.Int) (*felt.Felt, *felt.Felt) {
	// Create mask for low 128 bits (2^128 - 1)
	lowMask := new(big.Int)
	lowMask.Exp(big.NewInt(2), big.NewInt(128), nil)
	lowMask.Sub(lowMask, big.NewInt(1))

	// Extract low 128 bits
	low := new(big.Int).And(value, lowMask)

	// Extract high 128 bits by right-shifting by 128
	high := new(big.Int).Rsh(value, 128)

	return new(felt.Felt).SetBigInt(low), new(felt.Felt).SetBigInt(high)
}

// stringToByteArray converts a string to Cairo ByteArray structure
// Returns: [data_len, data_words..., pending_word, pending_word_len]
func stringToByteArray(s string) ([]*felt.Felt, error) {
	if s == "" {
		// Empty ByteArray: data_len=0, pending_word=0, pending_word_len=0
		return []*felt.Felt{
			new(felt.Felt).SetUint64(0), // data_len
			new(felt.Felt).SetUint64(0), // pending_word
			new(felt.Felt).SetUint64(0), // pending_word_len
		}, nil
	}

	bytes := []byte(s)
	length := len(bytes)

	// If string fits in pending_word (≤31 bytes), use simple structure
	if length <= 31 {
		// Convert string to hex and then to felt
		hexStr := fmt.Sprintf("0x%x", bytes)
		pendingWord, err := utils.HexToFelt(hexStr)
		if err != nil {
			return nil, fmt.Errorf("failed to convert string to felt: %w", err)
		}

		return []*felt.Felt{
			new(felt.Felt).SetUint64(0),              // data_len (no full words)
			pendingWord,                              // pending_word (the actual string data)
			new(felt.Felt).SetUint64(uint64(length)), // pending_word_len
		}, nil
	}

	// For longer strings, we'd need to split into multiple 31-byte words
	// For now, truncate to 31 bytes and warn
	// TODO: Implement proper multi-word ByteArray conversion
	truncated := bytes[:31]
	hexStr := fmt.Sprintf("0x%x", truncated)
	pendingWord, err := utils.HexToFelt(hexStr)
	if err != nil {
		return nil, fmt.Errorf("failed to convert truncated string to felt: %w", err)
	}

	return []*felt.Felt{
		new(felt.Felt).SetUint64(0),  // data_len (no full words)
		pendingWord,                  // pending_word (truncated string data)
		new(felt.Felt).SetUint64(31), // pending_word_len (truncated to 31)
	}, nil
}
