// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev DAO Operations dependencies.
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20VotesTimestamp} from "./extensions/ERC20VotesTimestamp.sol";

/// @dev Traversal dependencies.
import {NonBlockingReceiver} from "./extensions/NonBlockingReceiver.sol";

/// @dev Helpers.
import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";

/**
 * @title MetricToken
 * @dev The MetricToken contract is the main token of the Metric protocol. It is used to traverse
 *     to other chains, and is the main token used to interact with $METRIC protocol service
 *     offerings and providers.
 * @author @nftchance*
 */
contract MetricToken is
    ERC20,
    ERC20Permit,
    ERC20VotesTimestamp,
    NonBlockingReceiver
{
    /// @dev The max amount of tokens that can be minted.
    /// @notice 1,000,000,000 tokens minted to the deployer.
    uint256 public constant maxSupply = 1000000000000000000000000000;

    /// @dev The version of LayerZero being utilized.
    uint256 public constant layerZeroVersion = 1;

    /// @dev The LayerZeroPayment address.
    address public constant layerZeroPayment =
        0x0000000000000000000000000000000000000000;

    /// @dev The amount of gas to send to the destination chain to receive the tokens.
    uint256 public gasForDestinationLzReceive = 350000;

    ///@dev Encode adapterParams to specify more gas for the destination
    bytes public adapterParams =
        abi.encodePacked(layerZeroVersion, gasForDestinationLzReceive);

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////¡¡////////////////////////////////

    constructor(
        string memory _name,
        string memory _symbol,
        bool _psuedonymBound,
        address _layerZeroEndpoint
    )
        /// @dev Initialize all the dependencies
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        ERC20VotesTimestamp(_psuedonymBound)
    {
        /// @dev Mint the total supply of tokens to the deployer.
        _mint(_msgSender(), maxSupply);

        /// @dev Set the LayerZeroEndpoint address.
        endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);
    }

    ////////////////////////////////////////////////////
    ///                   SETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * @dev Allows any holder of $METRIC to traverse to another chain.
     * @notice This function is the main entry point for the protocol. It allows users
     *         to traverse to another chain, and use the protocol on that chain.
     * @param _chainId The chainId of the chain to traverse to.
     * @param _amount The amount of tokens to traverse.
     */
    function traverse(uint16 _chainId, uint256 _amount) public payable {
        /// @dev Load the address of the destination chain.
        bytes storage remoteAddress = orbitLookup[_chainId];

        /// @dev Confirm that the destination chain is currently in orbit.
        require(
            remoteAddress.length > 0,
            "MetricToken: This chain is not currently in orbit."
        );

        /// @dev Burn the tokens that are traversing to the destination chain to prevent
        ///      'double minting'.
        _burn(_msgSender(), _amount);

        ///@dev Encoding the payload with the values to send to the destination chain.
        bytes memory payload = abi.encode(_msgSender(), _amount);

        /// @dev Get the fees we need to pay to LayerZero + Relayer to cover message delivery
        /// @notice Surplus funding is refunded to the sender.
        (uint256 messageFee, ) = endpoint.estimateFees(
            _chainId,
            address(this),
            payload,
            false,
            adapterParams
        );

        /// @dev Confirm that the sender has sent enough funds to cover the traversal fee.
        require(
            msg.value >= messageFee,
            "MetricToken: msg.value not enough to cover traversal fee."
        );

        /// @dev Send the message to the destination chain.
        _lzSend(
            _chainId,
            payload,
            payable(_msgSender()),
            layerZeroPayment,
            adapterParams
        );
    }

    /**
     * @dev Safety function to set the gas for the destination chain to receive the tokens.
     * @notice This may only be needed in the future if a chain has a higher gas limit than
     *         the current default of 350,000.
     * @param _gasForDestinationLzReceive The amount of gas to send to the destination chain
     */
    function setGasForDestinationLzReceive(uint256 _gasForDestinationLzReceive)
        external
        onlyOwner
    {
        gasForDestinationLzReceive = _gasForDestinationLzReceive;
    }

    /**
     * @dev Allows MetricsDAO to begin operating on new chains.
     * @notice This functionality allows the DAO and protocol to grow with the ecosystem, and go where
     *         not only the users are, but what the chain is designed for. The needs of today, will not
     *         be the needs of tomorrow.
     * @param _chainId The chainId of the chain to add to the protocol.
     * @param _orbit The address of the chain to add to the protocol.
     */
    function setOrbit(uint16 _chainId, bytes calldata _orbit)
        external
        onlyOwner
    {
        orbitLookup[_chainId] = _orbit;
    }

    /**
     * @dev Call multiple functions at once.
     * @notice This function is not payable because it is intended as a non-payable function.
     * @param _data The data to call.
     * @return results The results of the calls.
     */
    function multicall(bytes[] calldata _data)
        external
        virtual
        returns (bytes[] memory results)
    {
        results = new bytes[](_data.length);
        for (uint256 i; i < _data.length; i++) {
            results[i] = _selfCall(_data[i]);
        }
    }

    ////////////////////////////////////////////////////
    ///               INTERNAL SETTERS               ///
    ////////////////////////////////////////////////////

    /**
     * See {NonBlockingReceiver-_LzReceive}.
     */
    function _LzReceive(
        uint16,
        bytes memory,
        uint64,
        bytes memory _payload
    ) internal override {
        /// @dev Decode the payload to get the address and amount of tokens traversing.
        (address to, uint256 amount) = abi.decode(_payload, (address, uint256));

        /// @dev mint the tokens back into existence on destination chain.
        _mint(to, amount);
    }

    /**
     * @dev Call a function on this contract.
     * @param _data The data to call.
     * @return result The result of the call.
     */
    function _selfCall(bytes memory _data) internal returns (bytes memory) {
        (bool success, bytes memory result) = address(this).delegatecall(_data);
        if (!success) {
            if (result.length < 68) revert("");
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }
        return result;
    }

    /**
     * See {ERC20VotesTimestamp-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20VotesTimestamp) {
        ERC20VotesTimestamp._beforeTokenTransfer(from, to, amount);
    }

    /**
     * See {ERC20VotesTimestamp-_afterTokenTransfer}.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20VotesTimestamp) {
        ERC20VotesTimestamp._afterTokenTransfer(from, to, amount);
    }

    /**
     * See {ERC20VotesTimestamp-_mint}.
     */
    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20VotesTimestamp)
    {
        ERC20VotesTimestamp._mint(to, amount);
    }

    /**
     * See {ERC20VotesTimestamp-_burn}.
     */
    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20VotesTimestamp)
    {
        ERC20VotesTimestamp._burn(account, amount);
    }
}
