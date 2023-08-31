// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Interfaces/IDigitalizationStore.sol";

contract DigitalizationStore is IDigitalizationStore, AccessControl {
    bytes32 public constant DIGITALIZATOR_ROLE = keccak256("DIGITALIZATOR");

    uint256 public freeDigitalizations_ = 3;
    uint256 public totalDigitalizations_ = 10000;

    mapping(address => uint256) private customerDigitalizations_;
    mapping(address => uint256) private customerFreeDigitalizations_;
    mapping(address => bool) private whitelistedCollections;

    constructor() {
        address _owner = _msgSender();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function changeFreeDigitalizations(
        uint256 _total
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        freeDigitalizations_ = _total;
    }

    function changeDigitalizations(
        uint256 _total
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        totalDigitalizations_ = _total;
    }

    function changeCollectionState(
        address _collection,
        bool _state
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedCollections[_collection] = _state;
    }

    function addFreeDigitalization(
        address _customer
    ) external override onlyRole(DIGITALIZATOR_ROLE) {
        customerFreeDigitalizations_[_customer] += 1;
    }

    function addDigitalization(
        address _customer
    ) external override onlyRole(DIGITALIZATOR_ROLE) {
        customerDigitalizations_[_customer] += 1;
    }

    function getFreeDigitalizations(
        address _customer
    ) external view override returns (uint256) {
        return customerFreeDigitalizations_[_customer];
    }

    function getDigitalizations(
        address _customer
    ) external view override returns (uint256) {
        return customerDigitalizations_[_customer];
    }

    function isWhitelisted(address _collection) external view override returns (bool) {
        return whitelistedCollections[_collection];
    }

    function canDigitalize(
        address _customer
    ) external view override returns (bool) {
        return customerDigitalizations_[_customer] < totalDigitalizations_;
    }

    function canFreeDigitalize(
        address _customer
    ) external view override returns (bool) {
        return customerFreeDigitalizations_[_customer] < freeDigitalizations_;
    }
}
