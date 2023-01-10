const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("MetricToken", function () {
  async function deployMetricTokenFixture() {
    // TODO: Add the layerZeroEndpoint. (I am not sure how to do this yet.)
    const layerZeroEndpoint = "";

    const name = "Metric Token";
    const symbol = "METRIC";
    const psuedonymBound = false;

    const [owner, otherAccount] = await ethers.getSigners();

    const MetricToken = await ethers.getContractFactory("MetricToken");
    const metricToken = await MetricToken.deploy(name, symbol, psuedonymBound, layerZeroEndpoint.address);

    return {
      metricToken,
      name,
      symbol,
      psuedonymBound,
      owner,
      otherAccount
    };
  }

  describe("Deployment", function () {
    // TODO: Test the owner.
    // TODO: Test the name and symbol.
    // TODO: Test the minting of the initial supply.
  });

  describe("Owner Controls", function () {
    // TODO: Test setGasForDestinationLzReceive.
    // TODO: Test setOrbit.
  })

  describe("Traversal", function () {
    // Note: Man we are getting dicey here. I am not sure how to test this but we will figure it out and prevail like the true heroes we are. (Copilot automatically wrote this and I liked it so much I kept it cause hell yeah!)

    // TODO: Test traverse.
    // TODO: Test a message failure.
  })
});
