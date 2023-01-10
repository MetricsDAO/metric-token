// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev Core dependencies.
import {IERC20VotesTimestamp} from "../interfaces/IERC20VotesTimestamp.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @dev Helpers.
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ERC20VotesTimestamp
 * @dev Extension of ERC20 to support Compound-like voting and delegation. This version is more generic than Compound's,
 *      and supports token supply up to 2^224^ - 1, while COMP is limited to 2^96^ - 1.
 * @dev This extension keeps a history (checkpoints) of each account's vote power. Vote power can be delegated either by calling 
 *         the {delegate} function directly, or by providing a signature to be used with {delegateBySig}. Voting power can be queried through 
 *         the public accessors {getVotes} and {getPastVotes}. By default, token balance does not account for voting power. This makes transfers 
 *         cheaper. The downside is that it requires users to delegate to themselves in order to activate checkpoints and have 
 *         their voting power tracked.
 * @notice This contract is a forked version of OpenZeppelins ERC20Votes contract, first modified by JokeDAO, and then again modified here
 *         for final clean-up. This implementation utilizes timestamps instead of blocks due to $METRIC being an omni-chain token.
 * @author @seanmc9* // @nftchance+
 */
abstract contract ERC20VotesTimestamp is IERC20VotesTimestamp, ERC20Permit {
    struct Checkpoint {
        uint256 fromTimestamp;
        uint224 votes;
    }

    ////////////////////////////////////////////////////
    ///                    STATE                     ///
    ////////////////////////////////////////////////////

    /// @dev The EIP-712 typehash for delegation under the contract's domain.
    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @dev The max amount of tokens that can be in circulation.
    uint256 public immutable maxSupply;

    /// @dev The total number of checkpoints for the supply of tokens.
    Checkpoint[] private _totalSupplyCheckpoints;

    /// @dev The address of the account which currently has administrative capabilities over this contract.
    mapping(address => address) private _delegates;

    /// @dev The voting checkpoints for each account, by index.
    mapping(address => Checkpoint[]) private _checkpoints;

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(string memory _name, uint256 _maxSupply) ERC20Permit(_name) {
        require(
            _maxSupply < type(uint224).max, 
            "ERC20VotesTimestamp: supply cap exceeded"
        );

        maxSupply = _maxSupply;
    }

    ////////////////////////////////////////////////////
    ///                   GETTERS                    ///
    ////////////////////////////////////////////////////

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos)
        public
        view
        virtual
        returns (Checkpoint memory)
    {
        return _checkpoints[account][pos];
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account)
        public
        view
        virtual
        returns (uint32)
    {
        return SafeCast.toUint32(_checkpoints[account].length);
    }

    /**
     * @dev Get the address `account` is currently delegating to.
     */
    function delegates(address account)
        public
        view
        virtual
        override
        returns (address)
    {
        return _delegates[account];
    }

    /**
     * @dev Gets the current votes balance for `account`
     */
    function getVotes(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Retrieve the number of votes for `account` at the end of `timestamp`.
     */
    function getPastVotes(address account, uint256 timestamp)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            timestamp < block.timestamp,
            "ERC20VotesTimestamp: block not yet mined"
        );
        return _checkpointsLookup(_checkpoints[account], timestamp);
    }

    /**
     * @dev Retrieve the `totalSupply` at the end of the block containing the timestamp `timestamp`.
     * @notice this value is the sum of all balances. It is but NOT the sum of all the delegated votes!
     */
    function getPastTotalSupply(uint256 timestamp)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            timestamp < block.timestamp,
            "ERC20VotesTimestamp: block not yet mined"
        );
        return _checkpointsLookup(_totalSupplyCheckpoints, timestamp);
    }

    ////////////////////////////////////////////////////
    ///               INTERNAL SETTERS               ///
    ////////////////////////////////////////////////////

    /**
     * @dev Lookup a value in a list of (sorted) checkpoints.
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 timestamp)
        private
        view
        returns (uint256)
    {
        uint256 high = ckpts.length;
        uint256 low;
        uint256 mid;

        while (low < high) {
            mid = Math.average(low, high);

            if (ckpts[mid].fromTimestamp > timestamp) {
                high = mid;
                break;
            }

            low = mid + 1;
        }

        return high == 0 ? 0 : ckpts[high - 1].votes;
    }

    /**
     * @dev Delegate votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) public virtual override {
        _delegate(_msgSender(), delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(
            block.timestamp <= expiry,
            "ERC20VotesTimestamp: signature expired"
        );

        address signer = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry)
                )
            ),
            v,
            r,
            s
        );

        require(
            nonce == _useNonce(signer),
            "ERC20VotesTimestamp: invalid nonce"
        );
        
        _delegate(signer, delegatee);
    }

    /**
     * @dev Snapshots the totalSupply after it has been increased.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);

        /// @dev This requirement is multi-function as it will prevent over-minting
        ///      as well as overflows for the voting process.
        require(
            totalSupply() <= maxSupply,
            "ERC20VotesTimestamp: total supply would exceed max supply"
        );

        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 amount) internal virtual override {
        super._burn(account, amount);

        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    /**
     * @dev Move voting power when tokens are transferred.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);

        _moveVotingPower(delegates(from), delegates(to), amount);
    }

    /**
     * @dev Change delegation for `delegator` to `delegatee`.
     */
    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate = delegates(delegator);
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[src],
                    _subtract,
                    amount
                );
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[dst],
                    _add,
                    amount
                );
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromTimestamp == block.timestamp) {
            ckpts[pos - 1].votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(
                Checkpoint({
                    fromTimestamp: block.timestamp,
                    votes: SafeCast.toUint224(newWeight)
                })
            );
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }
}
