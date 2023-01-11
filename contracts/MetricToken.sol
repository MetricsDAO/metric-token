// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {IOFTCore} from "./interfaces/IOFTCore.sol";
import {OFTCore} from "./extensions/OFTCore.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev DAO Operations dependencies.
import {ERC20VotesTimestamp} from "./extensions/ERC20VotesTimestamp.sol";

/// @dev Helpers.
import {IOFT} from "./interfaces/IOFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20VotesTimestamp} from "./interfaces/IERC20VotesTimestamp.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

/**
 * @title MetricToken
 * @dev The MetricToken contract is the main token of the Metric protocol. It is used to traverse
 *     to other chains, and is the main token used to interact with $METRIC protocol service
 *     offerings and providers.
 * @author @nftchance*
 */
contract MetricToken is IOFTCore, OFTCore, ERC20, ERC20VotesTimestamp {
    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        address _layerZeroEndpoint
    )
        /// @dev Initialize all the dependencies
        OFTCore(_layerZeroEndpoint)
        ERC20(_name, _symbol)
        ERC20VotesTimestamp(_name, _maxSupply)
    {
        /// @dev Mint the total supply of tokens to the deployer.
        _mint(_msgSender(), maxSupply);
    }

    ////////////////////////////////////////////////////
    ///                   SETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * @dev Call multiple functions at once.
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
    ///                   GETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * @dev See {IOFTCore-token}.
     */
    function token() public view virtual override returns (address) {
        return address(this);
    }

    /**
     * @dev See {IOFTCore-circulatingSupply}.
     */
    function circulatingSupply()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return totalSupply();
    }

    /**
     * @dev Returns whether `interfaceId` is supported by this contract.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return Whether `interfaceId` is supported.
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(OFTCore, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IOFT).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC20Permit).interfaceId ||
            interfaceId == type(IERC20VotesTimestamp).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    ////////////////////////////////////////////////////
    ///               INTERNAL SETTERS               ///
    ////////////////////////////////////////////////////

    /**
     * @dev See {OFTCore-_debitFrom}.
     */
    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        /// @dev If the spender is not the sender, then we need to check the allowance.
        address spender = _msgSender();

        /// @dev When the spender is not the sender, we need to decrease the allowance.
        if (_from != spender) _spendAllowance(_from, spender, _amount);

        /// @dev Burn the tokens.
        _burn(_from, _amount);

        /// @dev Return the amount.
        return _amount;
    }

    /**
     * @dev See {OFTCore-_creditTo}.
     */
    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        /// @dev Mint the tokens.
        _mint(_toAddress, _amount);

        /// @dev Return the amount.
        return _amount;
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
}
