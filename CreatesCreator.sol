// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./Interfaces/IDistributor.sol";

// The contract uses a combination between the backend and the blockchain to generate digital crates.
// When the users complete the transaction and the event is called the backend will generate the digital crate for the user

contract CrateCreator is AccessControl {
    event CreateCrate(
        address _owner,
        uint256 _type,
        uint256 _date,
        uint256 _amount
    );

    struct ContractInfo {
        uint8 distributionPercentage;
        uint8 developerPercentage;
        uint8 burningPercentage;
        uint8 rewardsPercentage;
        uint256 ethPrice;
        uint256 totalCreates;
        address distribution;
        address developer;
        address rewards;
        address FTB;
        uint256[] freeCrates;
    }

    bool payingChests = false;

    uint8 public devPercentage_ = 10;
    uint8 public distributionPercentage_ = 20;
    uint8 public burningPercentage_ = 10;

    uint256 public ethPrice_ = 100000000000000000;
    uint256 public totalCreates_ = 0;

    address public distribution_ = address(0);
    address public rewards_ = address(0);
    address public developer_ = address(0);
    address public FTB_ = address(0);
    address public burn_ = address(0x000000000000000D0e0A0D000000000000000000);

    mapping(address => mapping(uint256 => uint256)) private freeCrates_;
    mapping(address => mapping(uint256 => uint256)) private createPrice_;

    string constant INVALID_CREATE_ID = "INVALID_CREATE_ID";
    string constant INVALID_PAYMENT = "INVALID_PAYMENT";
    string constant WITHOUT_ALLOWANCE = "WITHOUT_ALLOWANCE";
    string constant INVALID_ETH_PAYMENT = "INVALID_ETH_PAYMENT";
    string constant NOT_ENOUGH_CRATES = "NOT_ENOUGH_CRATES";
    string constant INVALID_STATE = "INVALID_STATE";

    constructor(
        address _distribution,
        address _rewards,
        address _developer,
        address _FTB,
        uint8 _distributionPercentage,
        uint8 _burningPercentage
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        distributionPercentage_ = _distributionPercentage;
        burningPercentage_ = _burningPercentage;
        distribution_ = _distribution;
        rewards_ = _rewards;
        developer_ = _developer;

        //The FTB token can change baed on the deployed network, will be the FTB contract only on Meter and Polygon 
        FTB_ = _FTB;
    }

    //Toggle new payed chaest generations

    function togglePayingChests() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payingChests = !payingChests;
    }

    // Centralized updaters

    function changeAddresses(
        address _distribution,
        address _developer,
        address _FTB,
        address _rewards
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        distribution_ = _distribution;
        rewards_ = _rewards;
        developer_ = _developer;
        FTB_ = _FTB;
    }

    // Centralized updaters, we can change the distribution, developer and burning percentages based on the project behaviour. Normally the burning percentage will be 20%, the developer percentage will be 20% and the distribution percentage will be 60%

    function changePercentages(
        uint8 _developer,
        uint8 _distribution,
        uint8 _burning
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        distributionPercentage_ = _distribution;
        burningPercentage_ = _burning;
        devPercentage_ = _developer;
    }

    // Free crates manager
    // Add free crate to only one account using the crate type and the user address

    function addFreeCrates(
        address _user,
        uint256 _total,
        uint256 _type
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        freeCrates_[_user][_type] += _total;
    }

    // Add many free crates for all the users on the array

    function addFreeCratesForManyUsers(
        address[] calldata _users,
        uint256 _total,
        uint256 _type
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _users.length; i++) {
            addFreeCrates(_users[i], _total, _type);
        }
    }

    // Change the crate price using the type ID, the crate price will be related to a type and to a token address, so the ADMIN can change the price using different ERC20 tokens

    function setCratePrice(
        address _token,
        uint256 _id,
        uint256 _price
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        createPrice_[_token][_id] = _price;
    }

    // This is the DAPP fee, the admin can change the transaction fees, normally 0.1% from the transction fees on the network

    function setETHPrice(uint256 _price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ethPrice_ = _price;
    }

    //Validate if the crate has a price, if not the users can't buy it. Only the active crates will have a price

    function isValidCrate(
        address _token,
        uint256 _id
    ) public view returns (bool) {
        return createPrice_[_token][_id] > 0;
    }

    // The manager can get the crate price based on the crate type

    function getCratePricePerType(
        address _token,
        uint256 _id
    ) public view returns (uint256) {
        return createPrice_[_token][_id];
    }

    // Get how many free crate the user has

    function getFreeCratesPerType(
        address _user,
        uint256 _id
    ) public view returns (uint256) {
        return freeCrates_[_user][_id];
    }

    // Create only for the UI proposes, the manager can get all the crate prices using a token to identify it

    function getCreatePrices(
        address _token,
        uint256[] calldata _ids
    ) public view returns (uint256[] memory) {
        uint256[] memory _prices = new uint256[](_ids.length);

        for (uint256 i = 0; i < _ids.length; i++) {
            _prices[i] = getCratePricePerType(_token, _ids[i]);
        }

        return _prices;
    }

    // Create for the UI proposes, the manager can get all the free crates based on the crate type. So if the users has different free crates he can get all of this in only one call

    function getFreeCrates(
        address _user,
        uint256[] calldata _ids
    ) public view returns (uint256[] memory) {
        uint256[] memory _freeCrates = new uint256[](_ids.length);

        for (uint256 i = 0; i < _ids.length; i++) {
            _freeCrates[i] = getFreeCratesPerType(_user, _ids[i]);
        }

        return _freeCrates;
    }

    // UI proposes, the manager can get all the contract info in only one call

    function getContractInfo(
        address _user,
        uint256[] memory _crates
    ) public view returns (ContractInfo memory) {
        uint256[] memory _free = new uint256[](_crates.length);

        for (uint256 i = 0; i < _crates.length; i++) {
            _free[i] = freeCrates_[_user][_crates[i]];
        }

        return
            ContractInfo(
                distributionPercentage_,
                devPercentage_,
                burningPercentage_,
                100 -
                    distributionPercentage_ -
                    devPercentage_ -
                    burningPercentage_,
                ethPrice_,
                totalCreates_,
                distribution_,
                developer_,
                rewards_,
                FTB_,
                _free
            );
    }

    // If the user has free crates he can open it baed on the crate type
    // Validations
    // Validate if the user are paying necessary network fees to the contract
    // Validate if the user has free crates based on the type
    // Operations
    // Add new generated creates to the global totalCrates variable 
    // Reduce free crates to 0 because the user will earn all the available free crates
    // send the open crate event

    function openFreeCrates(uint256 _id) external payable {
        require(msg.value >= ethPrice_, INVALID_ETH_PAYMENT);
        address _user = _msgSender();
        uint256 _totalCrates = freeCrates_[_user][_id];
        require(_totalCrates > 0, NOT_ENOUGH_CRATES);
        totalCreates_ += _totalCrates;
        freeCrates_[_user][_id] = 0;
        emit CreateCrate(_user, _id, block.timestamp, _totalCrates);
    }

    // Generate crates using tokens
    // Validations
    // The contract is in the valid generation state
    // The user sent enough network fees to pay the transaction fees
    // Validate if the crate has a price > 0 using the isValidCrate  method
    // Operations
    // Get the crate price based on the type, token and on the crates amount
    // Redistribute the tokens amount using the distribution percentages
    // We will burn tokens only if the token is FTB, in the other case we will add the burning percentage to the distriobution percentage to buy FTB and the burn it
    // Distribute all the tokens to all the different addressess
    // Launch the createCrate event

    function buyCrates(
        IERC20 _token,
        uint256 _id,
        uint256 _amount
    ) external payable {
        require(payingChests, INVALID_STATE);

        require(msg.value >= ethPrice_, INVALID_ETH_PAYMENT);
        require(isValidCrate(address(_token), _id), INVALID_CREATE_ID);

        address _user = _msgSender();
        uint256 _price = createPrice_[address(_token)][_id] * _amount;

        uint256 _distPercentage = address(_token) == FTB_
            ? 0
            : 100 - devPercentage_;

        uint256 _burnPercentage = address(_token) == FTB_
            ? burningPercentage_
            : 0;

        uint256 _developer = (devPercentage_ * _price) / 100;
        uint256 _distribution = (_distPercentage * _price) / 100;
        uint256 _burning = (_burnPercentage * _price) / 100;
        uint256 _rewards = _price - _distribution - _burning - _developer;

        if (_distribution > 0) {
            require(
                _token.transferFrom(_user, distribution_, _distribution),
                INVALID_PAYMENT
            );

            IUniversalDistributor(distribution_).forceDistribution(
                address(_token),
                _distribution
            );
        }

        if ((_developer) > 0) {
            require(
                _token.transferFrom(_user, developer_, _developer),
                INVALID_PAYMENT
            );
        }

        if ((_rewards) > 0) {
            require(
                _token.transferFrom(_user, rewards_, _rewards),
                INVALID_PAYMENT
            );
        }

        if ((_burning) > 0) {
            require(
                _token.transferFrom(_user, burn_, _burning),
                INVALID_PAYMENT
            );
        }

        totalCreates_ += _amount;

        emit CreateCrate(_user, _id, block.timestamp, _amount);
    }

    // Withdraw transactions fees, only the admin can perform this action

    function withdrawETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(_msgSender()).transfer(address(this).balance);
    }
}
