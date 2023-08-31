// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Interfaces/IDigitalizationStore.sol";

// The contract create a connection between the backend and the blockchain using all launched events
// The propose of the contract is validate if the user has the NFT in the blockchain and if he has it he can digitalize it and use it on the game
// Only whitelisted collections can be digitalized

contract DigitalizationController is AccessControl {
    struct DigitalizationValues {
        uint256 burn;
        uint256 distribution;
        uint256 rewards;
        uint256 dev;
    }

    event Digitalization(
        address _collection,
        uint256 _id,
        address _owner,
        bool _free
    );

    uint8 public distributionPercentage_ = 10;
    uint8 public rewardsPercentage_ = 50;
    uint8 public burnPercentage_ = 20;

    uint256 public digitalizationPrice_ = 500000000000000000000;
    uint256 public ethPrice = 0;
    address public distribution_ = address(0);
    address public rewards_ = address(0);
    address public owner_ = address(0);
    address public burn_ = address(0x000000000000000D0e0A0D000000000000000000);

    IERC20 public token_;
    IDigitalizationStore public store_;

    string constant NOT_WHITELISTED_COLLECTION = "NOT_WHITELISTED_COLLECTION";
    string constant NOT_WHITELISTED_USER = "NOT_WHITELISTED_USER";
    string constant WITHOUT_DIGITALIZATIONS = "WITHOUT_DIGITALIZATIONS";
    string constant INVALID_PAYMENT = "INVALID_PAYMENT";
    string constant INVALID_NFT_OWNER = "INVALID_NFT_OWNER";
    string constant WITHOUT_ALLOWANCE = "WITHOUT_ALLOWANCE";
    string constant INVALID_DIGITALIZATION = "INVALID_DIGITALIZATION";
    string constant INVALID_ETH_PAYMENT = "INVALID_ETH_PAYMENT";

    constructor(
        address _distribution,
        address _rewards,
        address _token,
        address _ownerRewards,
        address _store,
        uint256 _price,
        uint8 _distributionPercentage,
        uint8 _burnPercentage,
        uint8 _rewardsPercentage
    ) {
        address _owner = _msgSender();

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);

        owner_ = _ownerRewards;
        rewards_ = _rewards;
        distribution_ = _distribution;

        distributionPercentage_ = _distributionPercentage;
        burnPercentage_ = _burnPercentage;
        rewardsPercentage_ = _rewardsPercentage;

        digitalizationPrice_ = _price;

        token_ = IERC20(_token);
        store_ = IDigitalizationStore(_store);
    }

    function changeDigitalizationStore(
        address _store
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        store_ = IDigitalizationStore(_store);
    }

    function changeAddresses(
        address _distribution,
        address _rewards,
        address _owner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        distribution_ = _distribution;
        rewards_ = _rewards;
        owner_ = _owner;
    }

    function changePercentages(
        uint8 _distribution,
        uint8 _burn,
        uint8 _rewards
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        distributionPercentage_ = _distribution;
        burnPercentage_ = _burn;
        rewardsPercentage_ = _rewards;
    }

    function changeDigitalizationPrice(
        uint256 _price,
        uint256 _ethPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        digitalizationPrice_ = _price;
        ethPrice = _ethPrice;
    }

    function getDigitalizationValues()
        public
        view
        returns (DigitalizationValues memory)
    {
        uint256 _distributionAmount = (distributionPercentage_ *
            digitalizationPrice_) / 100;

        uint256 _burnAmount = (burnPercentage_ * digitalizationPrice_) / 100;

        uint256 _rewardsAmount = (rewardsPercentage_ * digitalizationPrice_) /
            100;

        uint256 _devAmount = digitalizationPrice_ -
            _distributionAmount -
            _burnAmount -
            _rewardsAmount;

        return DigitalizationValues(
                _burnAmount,
                _distributionAmount,
                _rewardsAmount,
                _devAmount
            );
    }

    function digitalizeERC721(
        address _collection,
        uint256 _id
    ) external payable {
        address _user = _msgSender();

        require(msg.value >= ethPrice, INVALID_ETH_PAYMENT);
        require(store_.canDigitalize(_user), WITHOUT_DIGITALIZATIONS);
        require(store_.isWhitelisted(_collection), NOT_WHITELISTED_COLLECTION);
        require(IERC721(_collection).ownerOf(_id) == _user, INVALID_NFT_OWNER);

        DigitalizationValues memory values_ = getDigitalizationValues();

        if (values_.distribution > 0) {
            require(
                token_.transferFrom(_user, distribution_, values_.distribution),
                INVALID_PAYMENT
            );
        }

        if (values_.burn > 0) {
            require(
                token_.transferFrom(_user, burn_, values_.burn),
                INVALID_PAYMENT
            );
        }

        if (values_.rewards > 0) {
            require(
                token_.transferFrom(_user, rewards_, values_.rewards),
                INVALID_PAYMENT
            );
        }

        if (values_.dev > 0) {
            require(
                token_.transferFrom(_user, owner_, values_.dev),
                INVALID_PAYMENT
            );
        }

        store_.addDigitalization(_user);
        emit Digitalization(_collection, _id, _user, false);
    }

    function digitalizeFreeERC721(address _collection, uint256 _id) external payable {
        address _user = _msgSender();

        require(msg.value >= ethPrice, INVALID_ETH_PAYMENT);
        require(store_.isWhitelisted(_collection), NOT_WHITELISTED_COLLECTION);
        require(store_.canFreeDigitalize(_user), WITHOUT_DIGITALIZATIONS);
        require(IERC721(_collection).ownerOf(_id) == _user, INVALID_NFT_OWNER);

        store_.addFreeDigitalization(_user);
        emit Digitalization(_collection, _id, _user, true);
    }

    function digitalizeERC1155(address _collection, uint _id) external payable {
        address _user = _msgSender();

        require(msg.value >= ethPrice, INVALID_ETH_PAYMENT);
        require(store_.canDigitalize(_user), WITHOUT_DIGITALIZATIONS);
        require(store_.isWhitelisted(_collection), NOT_WHITELISTED_COLLECTION);

        require(
            IERC1155(_collection).balanceOf(_user, _id) > 0,
            INVALID_NFT_OWNER
        );

        DigitalizationValues memory values_ = getDigitalizationValues();

        if (values_.distribution > 0) {
            require(
                token_.transferFrom(_user, distribution_, values_.distribution),
                INVALID_PAYMENT
            );
        }

        if (values_.burn > 0) {
            require(
                token_.transferFrom(_user, burn_, values_.burn),
                INVALID_PAYMENT
            );
        }

        if (values_.rewards > 0) {
            require(
                token_.transferFrom(_user, rewards_, values_.rewards),
                INVALID_PAYMENT
            );
        }

        if (values_.dev > 0) {
            require(
                token_.transferFrom(_user, owner_, values_.dev),
                INVALID_PAYMENT
            );
        }

        store_.addDigitalization(_user);
        emit Digitalization(_collection, _id, _user, false);
    }

    function digitalizeFreeERC1155(
        address _collection,
        uint _id
    ) external payable {
        address _user = _msgSender();

        require(msg.value >= ethPrice, INVALID_ETH_PAYMENT);
        require(store_.canFreeDigitalize(_user), WITHOUT_DIGITALIZATIONS);
        require(store_.isWhitelisted(_collection), NOT_WHITELISTED_COLLECTION);

        require(
            IERC1155(_collection).balanceOf(_user, _id) > 0,
            INVALID_NFT_OWNER
        );

        store_.addFreeDigitalization(_user);
        emit Digitalization(_collection, _id, _user, true);
    }

    function withdrawETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(_msgSender()).transfer(address(this).balance);
    }
}
