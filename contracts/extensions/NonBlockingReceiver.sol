// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILayerZeroReceiver} from "../interfaces/ILayerZeroReceiver.sol";

/// @dev Helpers.
import {ILayerZeroEndpoint} from "../interfaces/ILayerZeroEndpoint.sol";

abstract contract NonBlockingReceiver is Ownable, ILayerZeroReceiver {
    ////////////////////////////////////////////////////
    ///                   STRUCT                     ///
    ////////////////////////////////////////////////////
    
    struct FailedMessages {
        uint256 payloadLength;
        bytes32 payloadHash;
    }

    ////////////////////////////////////////////////////
    ///                    STATE                     ///
    ////////////////////////////////////////////////////

    ILayerZeroEndpoint internal endpoint;

    mapping(uint16 => bytes) public orbitLookup;

    mapping(uint16 => mapping(bytes => mapping(uint256 => FailedMessages)))
        public failedMessages;

    ////////////////////////////////////////////////////
    ///                    EVENTS                    ///
    ////////////////////////////////////////////////////

    event MessageFailed(
        uint16 _srcChainId,
        bytes _srcAddress,
        uint64 _nonce,
        bytes _payload
    );

    ////////////////////////////////////////////////////
    ///                   SETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * See {ILayerZeroReceiver.lzReceive}
     */
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external override {
        /// @dev Only the LayerZeroEndpoint can call this function.
        require(msg.sender == address(endpoint));
        
        /// @dev Check that the source address is the correct address.
        require(
            _srcAddress.length == orbitLookup[_srcChainId].length &&
                keccak256(_srcAddress) ==
                keccak256(orbitLookup[_srcChainId]),
            "NonblockingReceiver: invalid source sending contract"
        );

        // try-catch all errors/exceptions
        // having failed messages does not block messages passing
        try this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload) {
            /// @dev There is no need to do anything here.
        } catch {
            /// @dev An error or exception occurred, so store the failed message.
            failedMessages[_srcChainId][_srcAddress][_nonce] = FailedMessages(
                _payload.length,
                keccak256(_payload)
            );

            /// @dev Emit an event to notify the user that a message failed.
            emit MessageFailed(_srcChainId, _srcAddress, _nonce, _payload);
        }
    }

    /**
     * @dev Confirm the sender of the message before processing the message.
     * @param _srcChainId The chain ID of the source chain.
     * @param _srcAddress The address of the source contract.
     * @param _nonce The nonce of the message.
     * @param _payload The payload containing the data to be processed.
     */
    function onLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        /// @dev Only allow internal transactions.
        require(
            msg.sender == address(this),
            "NonblockingReceiver: caller must be Bridge."
        );

        /// @dev Handle incoming message.
        _LzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    /**
     * @dev Allows the LayerZeroEndpoint to receive the tokens from the destination chain.
     * @notice This function is called by the LayerZeroEndpoint contract, and is only callable by
     *        the LayerZeroEndpoint contract.
     * @param _srcChainId The chain ID of the source chain.
     * @param _srcAddress The address of the source contract.
     * @param _nonce The nonce of the message.
     * @param _payload The payload containing the address and amount of tokens to receive.
     */
    function _LzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual;

    /**
     * @notice Send a message to LayerZero.
     * @param _dstChainId The chain ID of the destination chain.
     * @param _payload The payload of the message.
     * @param _refundAddress The address to refund any remaining value to.
     * @param _zroPaymentAddress The address to send ZRO payment to.
     * @param _txParam The transaction parameter of the message.
     */
    function _lzSend(
        uint16 _dstChainId,
        bytes memory _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes memory _txParam
    ) internal {
        /// @dev Send the message to the LayerZero endpoint contract.
        endpoint.send{value: msg.value}(
            _dstChainId,
            orbitLookup[_dstChainId],
            _payload,
            _refundAddress,
            _zroPaymentAddress,
            _txParam
        );
    }

    /**
     * @notice Retry a failed LayerZero message.
     * @param _srcChainId The chain ID of the source chain.
     * @param _srcAddress The address of the source contract.
     * @param _nonce The nonce of the message.
     * @param _payload The payload of the message.
     */
    function retryMessage(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external payable {
        /// @dev Get the failed message from storage (there may not be one).
        FailedMessages storage failedMsg = failedMessages[_srcChainId][
            _srcAddress
        ][_nonce];

        /// @dev Confirm that there is a failed message that needs retried.
        require(
            failedMsg.payloadHash != bytes32(0),
            "NonblockingReceiver: no stored message"
        );

        /// @dev Confirm that the payload matches the stored message.
        require(
            _payload.length == failedMsg.payloadLength &&
                keccak256(_payload) == failedMsg.payloadHash,
            "LayerZero: invalid payload"
        );

        /// @dev Clear the failed message from storage.
        failedMsg.payloadLength = 0;
        failedMsg.payloadHash = bytes32(0);

        /// @dev Try the message again, and revert if it fails again.
        this.onLzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }
}