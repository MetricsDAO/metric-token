const { task } = require("hardhat/config");

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

task("increment", "Increments the nonce by 1")
  .setAction(async (taskArgs, hre) => {
    const [deployer] = await ethers.getSigners();
    console.log(`✅ Connected to ${deployer.address}`);

    console.log('✅ Incrementing nonce by 1')
    await deployer.sendTransaction({ to: deployer.address, value: 0 })

    console.log('✅ Done')
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
      "Metric",
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
      constructorArguments: [
        "Metric",
        "METRIC",
        layerZeroDecimals,
        layerZeroEndpoint
      ],
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
    gasPrice: 67,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    showMethodSig: true,
    showTimeSpent: true,
  },
  networks: {
    hardhat: {
      chainId: 1337,
      gas: "auto",
      gasPrice: "auto",
      saveDeployments: false,
      mining: {
        auto: false,
        order: 'fifo',
        interval: 1500,
      },
      allowUnlimitedContractSize: true
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ETH_ALCHEMY_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gasPrice: 60000000000,
      allowUnlimitedContractSize: true
    }
  }
};