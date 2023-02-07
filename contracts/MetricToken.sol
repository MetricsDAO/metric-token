// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.17;

/// @dev Core dependencies.
import {BaseOFTV2} from "./extensions/BaseOFTV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @title MetricToken
 * @dev The MetricToken contract is the main token of the Metric protocol. It is used to traverse
 *     to other chains, and is the main token used to interact with $METRIC protocol service
 *     offerings and providers.
 * @author @CHANCE*
 */
contract MetricToken is BaseOFTV2, ERC20, ERC20Permit, ERC20Votes {
    ////////////////////////////////////////////////////
    ///                    STATE                     ///
    ////////////////////////////////////////////////////

    uint256 internal immutable ld2sdRate;

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintSupply,
        uint8 _sharedDecimals,
        address _layerZeroEndpoint
    )
        /// @dev Initialize all the dependencies
        BaseOFTV2(_sharedDecimals, _layerZeroEndpoint)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        /// @dev Retrieve the token decimals.
        uint8 tokenDecimals = decimals();

        /// @dev Ensure that the shared decimals is less than or equal to the token decimals.
        require(
            _sharedDecimals <= tokenDecimals,
            "OFT: sharedDecimals must be <= decimals"
        );

        /// @dev Calculate the ld2sdRate.
        ld2sdRate = 10**(tokenDecimals - _sharedDecimals);

        /// @dev Mint the total supply of tokens to the deployer.
        _mint(_msgSender(), _mintSupply);
    }

    ////////////////////////////////////////////////////
    ///                   GETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * @dev Retrieve the circulating supply of the token on this chain.
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
     * @dev Retrieve the address of this token.
     */
    function token() public view virtual override returns (address) {
        return address(this);
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
        bytes32,
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
     * @dev See {ERC20-_transferFrom}.
     */
    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        /// @dev Get the sender of the message.
        address spender = _msgSender();

        /// @dev If transfer from this contract, no need to check allowance.
        if (_from != address(this) && _from != spender)
            _spendAllowance(_from, spender, _amount);

        /// @dev Transfer the tokens.
        _transfer(_from, _to, _amount);

        /// @dev Return the amount.
        return _amount;
    }

    /**
     * See {ERC20Votes-_afterTokenTransfer}.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
     * See {ERC20Votes-_mint}.
     */
    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    /**
     * See {ERC20Votes-_burn}.
     */
    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    ////////////////////////////////////////////////////
    ///               INTERNAL GETTERS               ///
    ////////////////////////////////////////////////////

    /**
     * @dev Returns the ld2sdRate.
     */
    function _ld2sdRate() internal view virtual override returns (uint256) {
        return ld2sdRate;
    }
}
