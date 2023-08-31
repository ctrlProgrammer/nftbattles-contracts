// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IVoltswapRouter.sol";

// The universal distributor will works on Meter to BUY and BURN FTB directly on the Voltswap protocol
// It works using the fees from all the digitalization, crate creator and other contracts
// The contract will be deployed only on the Meter chain

abstract contract IUniversalDistributor is Context, AccessControl {
    bytes32 public constant SOFT_ROLE = keccak256("SOFT_ROLE");

    struct Info {
        uint8 buyBurnPercentage;
        uint8 stakingPercentage;
        address[] tokens;
        uint256[] balances;
    }

    string public constant PAYMENT = "UN: payment";
    string public constant INVALID_TOKEN = "UN: invalid token";

    address public constant DEAD_ = 0x000000000000000D0e0A0D000000000000000000;

    mapping(address => Router.route[]) internal routes_;

    Router internal router_;

    uint8 internal buyBurnPercentage_ = 80;
    uint8 internal stakingPercentage_ = 20;
    uint8 internal savingPercentage_ = 100;

    address internal pool_ = address(0);

    address[] internal tokens_;

    function setConfig(
        uint8 _buyBurnPercentage,
        uint8 _stakingPercentage,
        uint8 _savingPercentage,
        address _router,
        address _stakingPool
    ) external virtual;

    function setTokens(address[] memory _t) external virtual;

    function getData() external view virtual returns (Info memory);

    function balance(address _token) public view virtual returns (uint256);

    function getBalances() public view virtual returns (uint256[] memory);

    function preApprove(address _token, address _spender) public virtual;

    function preApproveAll(address _spender) external virtual;

    function instaDistribute(address _token, uint256 _amount) external virtual;

    function withdraw(address _token, uint256 _amount) external virtual;

    function forceDistribution(
        address _token,
        uint256 _amount
    ) external virtual;
}
