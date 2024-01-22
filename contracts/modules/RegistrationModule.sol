// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { BaseModule } from "contracts/modules/BaseModule.sol";
import { IIPMetadataResolver } from "contracts/interfaces/resolvers/IIPMetadataResolver.sol";
import { REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";

/// @title Registration Module
/// @notice The registration module is responsible for registration of IP into
///         the protocol. During registration, this module will register an IP
///         into the protocol, create a resolver, and bind to it any licenses
///         and terms specified by the IP registrant (IP account owner).
contract RegistrationModule is BaseModule {
    /// @notice The metadata resolver used by the registration module.
    IIPMetadataResolver public resolver;

    /// @notice Initializes the registration module contract.
    /// @param controller The access controller used for IP authorization.
    /// @param recordRegistry The address of the IP record registry.
    /// @param accountRegistry The address of the IP account registry.
    /// @param licenseRegistry The address of the license registry.
    /// @param resolverAddr The address of the IP metadata resolver.
    constructor(
        address controller,
        address recordRegistry,
        address accountRegistry,
        address licenseRegistry,
        address resolverAddr
    ) BaseModule(controller, recordRegistry, accountRegistry, licenseRegistry) {
        resolver = IIPMetadataResolver(resolverAddr);
    }

    /// @notice Registers a root-level IP into the protocol. Root-level IPs can
    ///         be thought of as organizational hubs for encapsulating policies
    ///         that actual IPs can use to register through. As such, a
    ///         root-level IP is not an actual IP, but a container for IP policy
    ///         management for their child IP assets.
    /// TODO: Rethink the semantics behind "root-level IPs" vs. "normal IPs".
    /// TODO: Update function parameters to utilize a struct instead.
    /// TODO: Revisit requiring binding an existing NFT to a "root-level IP".
    ///       If root-level IPs are an organizational primitive, why require NFTs?
    /// TODO: Change to a different resolver optimized for root IP metadata.
    /// @param policyId The policy that identifies the licensing terms of the IP.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    function registerRootIp(uint256 policyId, address tokenContract, uint256 tokenId) external returns (address) {
        // Perform registrant authorization.
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or root-IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        // Perform core IP registration and IP account creation.
        address ipId = IP_RECORD_REGISTRY.register(block.chainid, tokenContract, tokenId, address(resolver), true);

        // Perform core IP policy creation.
        if (policyId != 0) {
            // If we know the policy ID, we can register it directly on creation.
            // TODO: return policy index
            LICENSE_REGISTRY.addPolicyToIp(ipId, policyId);
        }

        return ipId;
    }

    /// @notice Registers an IP derivative into the protocol.
    /// @param licenseId The license to incorporate for the new IP.
    /// @param tokenContract The address of the NFT bound to the derivative IP.
    /// @param tokenId The token id of the NFT bound to the derivative IP.
    /// @param ipName The name assigned to the new IP.
    /// @param ipDescription A string description to assign to the IP.
    /// @param hash The content hash of the IP being registered.
    function registerDerivativeIp(
        uint256 licenseId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        string memory ipDescription,
        bytes32 hash
    ) external {
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        // Perform core IP registration and IP account creation.
        address ipId = IP_RECORD_REGISTRY.register(block.chainid, tokenContract, tokenId, address(resolver), true);
        ACCESS_CONTROLLER.setPermission(ipId, address(this), address(resolver), IIPMetadataResolver.setMetadata.selector, 1);

        // Perform core IP derivative licensing - the license must be owned by the caller.
        // TODO: return resulting policy index
        LICENSE_REGISTRY.linkIpToParent(licenseId, ipId, msg.sender);

        // Perform metadata attribution setting.
        resolver.setMetadata(
            ipId,
            IP.MetadataRecord({
                name: ipName,
                description: ipDescription,
                hash: hash,
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: ""
            })
        );
    }

    /// @notice Gets the protocol-wide module identifier for this module.
    function name() public pure override returns (string memory) {
        return REGISTRATION_MODULE_KEY;
    }
}
