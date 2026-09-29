// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IExerciceSolution.sol";

contract MyCryptoZoo is ERC721Enumerable, Ownable, IExerciceSolution {
    uint256 private _nextTokenId;
    uint256 public constant REGISTRATION_PRICE = 0.00001 ether; 

    struct Animal {
        string name;
        bool wings;
        uint256 legs;
        uint256 sex;
        uint256 parent1;
        uint256 parent2;
    }

    mapping(uint256 => Animal) public animals;
    mapping(address => bool) public breeders;
    
    // Market Data
    mapping(uint256 => uint256) public prices;
    mapping(uint256 => bool) public forSale;

    // Reproduction Data
    mapping(uint256 => uint256) public reproPrices;
    mapping(uint256 => bool) public canRepro;
    mapping(uint256 => address) public authorizedToBreed;

    constructor() ERC721("CryptoZoo", "ZOO") Ownable(msg.sender) {
        _nextTokenId = 1;
        breeders[msg.sender] = true;
        breeders[0xB6C6cf310456Bd0dEE01162A9150EC7ccA146936] = true;
    }

    modifier onlyBreeder() {
        require(breeders[msg.sender], "Not a breeder");
        _;
    }

    
    function tokenOfOwnerByIndex(address owner, uint256 index) 
        public 
        view 
        override(ERC721Enumerable, IExerciceSolution) 
        returns (uint256) 
    {
        return super.tokenOfOwnerByIndex(owner, index);
    }

    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721Enumerable, IERC165) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    // access control


    function isBreeder(address account) external view returns (bool) {
        return breeders[account];
    }

    function registrationPrice() external pure returns (uint256) {
        return REGISTRATION_PRICE;
    }


    function registerMeAsBreeder() external payable {
        require(msg.value >= REGISTRATION_PRICE, "Not enough ETH");
        breeders[msg.sender] = true;
    }

    // animal logic

    function declareAnimal(uint sex, uint legs, bool wings, string calldata name) external onlyBreeder returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        animals[tokenId] = Animal(name, wings, legs, sex, 0, 0);
        return tokenId;
    }

    function declareAnimalWithParents(uint sex, uint legs, bool wings, string calldata name, uint parent1, uint parent2) external onlyBreeder returns (uint256) {
        if (ownerOf(parent2) != msg.sender && canRepro[parent2]) {
             require(authorizedToBreed[parent2] == msg.sender, "Not authorized");
             delete authorizedToBreed[parent2];
        }

        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        animals[tokenId] = Animal(name, wings, legs, sex, parent1, parent2);
        return tokenId;
    }

    function declareDeadAnimal(uint animalNumber) external {
        require(ownerOf(animalNumber) == msg.sender, "Not owner");
        _burn(animalNumber);
        delete animals[animalNumber];
        delete forSale[animalNumber];
        delete canRepro[animalNumber];
        delete authorizedToBreed[animalNumber];
    }

    function getAnimalCharacteristics(uint animalNumber) external view returns (string memory _name, bool _wings, uint _legs, uint _sex) {
        Animal memory a = animals[animalNumber];
        return (a.name, a.wings, a.legs, a.sex);
    }

    function getParents(uint animalNumber) external view returns (uint256, uint256) {
        return (animals[animalNumber].parent1, animals[animalNumber].parent2);
    }

    // sales

    function isAnimalForSale(uint animalNumber) external view returns (bool) {
        return forSale[animalNumber];
    }

    function animalPrice(uint animalNumber) external view returns (uint256) {
        return prices[animalNumber];
    }

    function offerForSale(uint animalNumber, uint price) external {
        require(ownerOf(animalNumber) == msg.sender, "Not owner");
        prices[animalNumber] = price;
        forSale[animalNumber] = true;
    }

    function buyAnimal(uint animalNumber) external payable {
        require(forSale[animalNumber], "Not for sale");
        require(msg.value >= prices[animalNumber], "Insufficient payment");

        address seller = ownerOf(animalNumber);
        forSale[animalNumber] = false;
        prices[animalNumber] = 0;

        _transfer(seller, msg.sender, animalNumber);
        payable(seller).transfer(msg.value);
    }

    // reproduction

    function canReproduce(uint animalNumber) external view returns (bool) {
        return canRepro[animalNumber];
    }

    function reproductionPrice(uint animalNumber) external view returns (uint256) {
        return reproPrices[animalNumber];
    }

    function authorizedBreederToReproduce(uint animalNumber) external view returns (address) {
        return authorizedToBreed[animalNumber];
    }

    function offerForReproduction(uint animalNumber, uint priceOfReproduction) external returns (uint256) {
        require(ownerOf(animalNumber) == msg.sender, "Not owner");
        reproPrices[animalNumber] = priceOfReproduction;
        canRepro[animalNumber] = true;
        return priceOfReproduction;
    }


    function payForReproduction(uint animalNumber) external payable {
        require(canRepro[animalNumber], "Not available");
        require(msg.value >= reproPrices[animalNumber], "Insufficient payment");

        address owner = ownerOf(animalNumber);
        authorizedToBreed[animalNumber] = msg.sender;
        payable(owner).transfer(msg.value);
    }
}