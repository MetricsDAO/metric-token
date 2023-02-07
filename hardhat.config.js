require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require('hardhat-deploy');
require("hardhat-gas-reporter");

require("dotenv").config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("deploy", "Deploys $METRIC to the network")
  .addOptionalParam("verify", "Verify the deployed contracts on Etherscan", false, types.boolean)
  .setAction(async (taskArgs, hre) => {
    await hre.run('compile');

    const [deployer] = await ethers.getSigners();
    console.log(`✅ Connected to ${deployer.address}`);

    const chainId = await getChainId()
    console.log('✅ Connected to chain ' + chainId)

    const layerZeroDecimals = 5
    const layerZeroEndpoint = '0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675'

    const MetricToken = await ethers.getContractFactory("MetricToken");
    let metricToken = await MetricToken.deploy(
      "Metric Token",
      "METRIC",
      layerZeroDecimals,
      layerZeroEndpoint
    );
    metricToken = await metricToken.deployed();
    console.log("✅ MetricToken Deployed.")

    metricDeployment = {
      "Deployer": deployer.address,
      "MetricToken Address": metricToken.address,
      "Remaining ETH Balance": parseInt((await deployer.getBalance()).toString()) / 1000000000000000000,
    }
    console.table(metricDeployment)

    if (chainId == '31337' || taskArgs.verify === false) return;

    await new Promise(r => setTimeout(r, 30000));
    await hre.run("verify:verify", {
      address: metricToken.address,
      constructorArguments: [],
    });
    console.log("✅ MetricToken verified.")

  });

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000
          }
        }
      }
    ],
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
    }
  },
  gasReporter: {
    enabled: true,
    currency: 'USD',
    gasPrice: 20,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    showMethodSig: true,
    showTimeSpent: true,
  },
  networks: {
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ETH_ALCHEMY_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gasPrice: 30000000000,
    }
  }
};