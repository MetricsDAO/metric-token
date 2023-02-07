const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");

describe("MetricToken", function () {
  async function deployMetricTokenFixture() {
    const layerZeroDecimals = 10

    const name = "Metric Token";
    const symbol = "METRIC";
    const psuedonymBound = false;

    const [owner, otherAccount] = await ethers.getSigners();

    const LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
    const localChainId = 1;
    const lzEndpointMock = await LZEndpointMock.deploy(localChainId);

    const MetricToken = await ethers.getContractFactory("MetricToken");
    const metricToken = await MetricToken.deploy(name, symbol, layerZeroDecimals, lzEndpointMock.address);

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
    it("Should deploy properly.", async function () {
      const { metricToken, name, symbol } = await loadFixture(deployMetricTokenFixture);

      expect(await metricToken.name()).to.equal(name);
      expect(await metricToken.symbol()).to.equal(symbol);

      // Commented out because it only mints on mainnet.
      // expect(await metricToken.totalSupply()).to.equal(1000000000);
    });
  });
});
