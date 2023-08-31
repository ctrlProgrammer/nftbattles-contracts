// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract IDigitalizationStore {
    function changeFreeDigitalizations(uint256 _total) external virtual;

    function changeDigitalizations(uint256 _total) external virtual;

     function changeCollectionState(
        address _collection,
        bool _state
    ) external virtual;

    function addFreeDigitalization(address _customer) external virtual;

    function addDigitalization(address _customer) external virtual;

    function getFreeDigitalizations(
        address _customer
    ) external view virtual returns (uint256);

    function getDigitalizations(
        address _customer
    ) external view virtual returns (uint256);

    function canDigitalize(
        address _customer
    ) external view virtual returns (bool);

    function canFreeDigitalize(
        address _customer
    ) external view virtual returns (bool);

    function isWhitelisted(address _collection) external view virtual returns (bool);
}
