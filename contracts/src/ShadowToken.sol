// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {ERC6372Utils} from "@openzeppelin/contracts/utils/ERC6372Utils.sol";

/**
 * @author 0xshdwfx
 * @title Shadow Governance Token
 * @notice ERC-20 governance token with delegation, checkpoints, and permit approvals.
 * @dev The complete initial supply is minted to the deployer during construction.
 */
contract ShadowToken is ERC20, ERC20Permit, ERC20Votes {
    /**
     * @notice Deploys the Shadow governance token and mints the initial supply to the deployer.
     */
    constructor() ERC20("Shadow", "SHDW") ERC20Permit("Shadow") {
        _mint(msg.sender, 1_000_000e18);
    }

    ///////////////////////////
    /// Function Overrides ///
    /////////////////////////

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function clock() public view virtual override returns (uint48) {
        return Time.timestamp();
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function CLOCK_MODE() public view virtual override returns (string memory) {
        return ERC6372Utils.timestampClockMode(clock);
    }
}
