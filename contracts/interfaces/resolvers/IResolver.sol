// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "contracts/interfaces/modules/base/IModule.sol";

/// @notice Resolver Interface
interface IResolver is IModule {

    /// @notice Checks whether the resolver IP interface is supported.
    function supportsInterface(bytes4 id) view external returns (bool);

}
