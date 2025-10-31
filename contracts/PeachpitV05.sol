// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {ERC721Utils} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol";

/**
 * @title Peachpit
 * @author Merrill B. Lamont III (rockopera.eth)
 * @notice Own and name a color. 1 NFT color swatch for each of 16M+ web colors.
 * @dev All on-chain: this NFT is a deed of ownership, but for a digital asset that is contained within the NFT.
 */
contract PeachpitV04 is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // For mapping a token's ID to a token's name.
    mapping(uint => string) private _names;

    // For converting from the decimal to the hexadecimal number system.
    bytes16 private constant _HEX_SYMBOLS = "0123456789ABCDEF";

    uint private constant _MINTPRICE = 0.001 ether;

    event Rename(
        string indexed oldName,
        string indexed newName,
        uint indexed tokenId
    );

    event UpgradeabilityEnded(address upgradeabilityEnder);

    event Withdrew(uint amount);

    event LogDepositReceived(address sender, uint amount);

    /**
     * @notice Initializes the contract.
     * @dev I'll likely update these to reflect when this is ready for mainnet.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC721_init("Peachpit", "PCH");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function endUpgradeability() public onlyOwner {
        StorageSlot
            .getBooleanSlot(
                bytes32(
                    uint256(keccak256("eip1967.proxy.upgradeabilityEnded")) - 1
                )
            )
            .value = true;

        emit UpgradeabilityEnded(msg.sender);
    }

    function upgradeabilityEnded() public view returns (bool) {
        return
            StorageSlot
                .getBooleanSlot(
                    bytes32(
                        uint256(
                            keccak256("eip1967.proxy.upgradeabilityEnded")
                        ) - 1
                    )
                )
                .value;
    }

    function _authorizeUpgrade(address) internal view override onlyOwner {
        require(
            !upgradeabilityEnded(),
            "This contract is no longer upgradeable."
        );
    }

    /**
     * @notice Creates a token.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @param name Color's name.
     */
    function setToken(
        string memory colorhex,
        string memory name
    ) public payable {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        _setToken(tokenId, name);
    }

    function _setToken(
        uint tokenId,
        string memory name
    ) private onlyIfSufficientFunds(tokenId) {
        // require(tokenId < 16777216, "too big number");
        _mint(msg.sender, tokenId); // creates token (first ensures token doesn't exist)
        _modName(tokenId, name); // names token
        ERC721Utils.checkOnERC721Received(
            _msgSender(),
            address(0),
            msg.sender,
            tokenId,
            ""
        ); // ensures that, if token recipient is a contract, then it can handle receiving tokens
        // WARNING: minting is a source of reentrancy: it calls IERC721Receiver().onERC721received()
        // SO #1: generally, keep the minting process simple
        // SO #2: specifically, make this _setToken() a safer _safeMint() by:
        // ...putting both _mint() & _modName() "effects" before the checkOnERC721Received() "interaction"
        // OLD: _safeMint(msg.sender, tokenId, ""); // creates token (first ensures token doesn't exist)
        // OLD: _modName(tokenId, name); // names token
    }

    modifier onlyIfSufficientFunds(uint tokenId) {
        if (tokenId == 0 || tokenId == 16777215) {
            // extra premium pricing for: black, white
            require(
                msg.value >= (10000 * _MINTPRICE),
                "Insufficient payment for an extra premium color."
            ); // should be 10000 * _MINTPRICE (10 ETH)
        } else if (
            tokenId == 255 ||
            tokenId == 65280 ||
            tokenId == 16711680 ||
            tokenId == 65535 ||
            tokenId == 16711935 ||
            tokenId == 16776960
        ) {
            // premium pricing for: blue, green, red, cyan, magenta, yellow
            require(
                msg.value >= (1000 * _MINTPRICE),
                "Insufficient payment for a premium color."
            ); // should be 1000 * _MINTPRICE (1 ETH)
        } else {
            // regular pricing for: the rest of the Web Colors
            require(
                msg.value >= _MINTPRICE,
                "Insufficient payment for a regular color."
            ); // should be _MINTPRICE (0.001 ETH)
        }
        _;
    }

    function withdraw() public onlyOwner {
        // gotta ensure the checks-effects-interactions pattern is always in here
        uint balanceOfThisContract = address(this).balance;
        require(balanceOfThisContract > 0, "Nothing to withdraw.");
        (bool success, ) = owner().call{value: balanceOfThisContract}(""); // call() doesn't require owner() wrapped in payable()
        require(success, "Withdrawal failed.");
        // OLD: payable(owner()).transfer(balanceOfThisContract);
        emit Withdrew(balanceOfThisContract);
    }

    receive() external payable {
        emit LogDepositReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit LogDepositReceived(msg.sender, msg.value);
    }

    /**
     * @notice Destroys a token.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     */
    function nixToken(string memory colorhex) public {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        _nixToken(tokenId);
    }

    function _nixToken(uint tokenId) private onlyOwnerOf(tokenId) {
        // require(tokenId < 16777216, "too big number");
        _modName(tokenId, ""); // de-names token
        _burn(tokenId); // destroys token (burn function doesn't check for owner-approval, so modifier does, also ensuring existence)
        // _names[tokenId] = ""; // de-names token
    }

    /**
     * @notice Retrieves a token's owner.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @return Token's owner.
     */
    function getOwner(string memory colorhex) public view returns (address) {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        return _getOwner(tokenId);
    }

    function _getOwner(uint tokenId) private view returns (address) {
        // require(tokenId < 16777216, "too big number");
        return ownerOf(tokenId); // gets token's owner (first ensures token exists)
    }

    /**
     * @notice Changes a token's owner.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @param newOwner Token's new owner.
     */
    function modOwner(string memory colorhex, address newOwner) public {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        _modOwner(tokenId, newOwner);
    }

    function _modOwner(uint tokenId, address newOwner) private {
        // require(tokenId < 16777216, "too big number");
        require(
            newOwner != address(this),
            "New token owner cannot be proxy contract."
        );
        _safeTransfer(msg.sender, newOwner, tokenId); // gives token (first ensures token exists and is owned)
    }

    /**
     * @notice Retrieves a color's name.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @return Color's name.
     */
    function getName(
        string memory colorhex
    ) public view returns (string memory) {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        require(_getOwner(tokenId) != address(0), "token doesn't exist"); // token exists
        return _getName(tokenId);
    }

    function _getName(uint tokenId) private view returns (string memory) {
        // require(tokenId < 16777216, "too big number");
        return _names[tokenId]; // gets token's name
    }

    /**
     * @notice Changes a color's name.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @param newName Color's new name.
     */
    function modName(string memory colorhex, string memory newName) public {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        _modName(tokenId, newName);
    }

    function _modName(
        uint tokenId,
        string memory newName
    ) private onlyOwnerOf(tokenId) {
        // removed modifier: onlyValidName(newName)
        // require(tokenId < 16777216, "too big number");
        string memory oldName = _getName(tokenId);
        _names[tokenId] = newName; // rename token (first ensures token is owned, which also ensures that it exists)
        emit Rename(oldName, newName, tokenId);
    }

    /**
     * @notice Retrieves a token's picture.
     * @dev Validates colorhex, then passes to a private function to actually do it.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @return Token's metadata, which includes a SVG-coded picture.
     */
    function getPic(
        string memory colorhex
    ) public view returns (string memory) {
        uint tokenId = validateColorhexAndGetId(colorhex); // gets tokenId
        return _getPic(tokenId);
    }

    function _getPic(uint tokenId) private view returns (string memory) {
        // removed the function modifier: onlyExistentToken(tokenId)
        // require(tokenId < 16777216, "too big number");
        require(_getOwner(tokenId) != address(0), "token doesn't exist"); // token owner is not the burn address
        return tokenURI(tokenId); // gets token's pic
    }

    /*
    modifier onlyValidName(string memory n) {
        require(bytes(n).length < 25, "name too long"); // max length: 24 characters
        // eventually; it("can not accept a multi-line name");

        // THIS is where I should check for code injection vulnerabilities
        _;
    }
    */

    modifier onlyOwnerOf(uint tokenId) {
        require(_getOwner(tokenId) == msg.sender, "not the owner"); // token owner is current user
        _;
    }

    /*
    modifier onlyExistentToken(uint tokenId) {
        require(_getOwner(tokenId) != address(0), "token doesn't exist"); // token owner is not the burn address
        _;
    }
    */

    /**
     * @notice Converts a color's colorhex into its tokenId: the token's internal ID.
     * @dev Validates and converts a colorhex hexadecimal string into a decimal integer: the tokenId.
     * @param colorhex Color's 6-digit hexadecimal representation.
     * @return n Color's tokenId.
     */
    function validateColorhexAndGetId(
        string memory colorhex
    ) public pure returns (uint n) {
        // decimal number 'n' is birthed, to be constructed, then returned
        require(bytes(colorhex).length == 6, "improper size");
        // color-hexadecimal number is iterated through, but starting with lowest numeral
        for (uint i = 0; i < 6; ++i) {
            // hexadecimal numeral is represented as its place (0-127) within the ASCII character mapping
            uint a = uint8(bytes(colorhex)[5 - i]);
            // ASCII 0-9: decimal 0-9
            if (a >= 48 && a <= 57) {
                n += (a - 48) * (16 ** i);
            }
            // ASCII A-F: decimal 10-15
            else if (a >= 65 && a <= 70) {
                n += (a - 55) * (16 ** i);
            }
            // ASCII a-f: decimal 10-15
            else if (a >= 97 && a <= 102) {
                n += (a - 87) * (16 ** i);
            }
            // incoming string was not completely made of ASCII characters mapping to valid hexadecimal numerals
            else {
                revert("Invalid color-hexadecimal string.");
            }
        }
        // decimal number is the sum of the hexadecimal values in the hexadecimal number system's places (units, 16's, 256's, etc., instead of units, 10's, 100's, etc.)

        // ...next line should probably be an 'assert', since it is critical internal logic
        // require(n < 16777216, "too large tokenId"); // just should NOT happen, based on above construction
        assert(n < 16777216);
        return n;
    }

    /**
     * @notice Converts a token's tokenId into its colorhex: the color's 6-digit hexadecimal code.
     * @dev Validates and converts a tokenId decimal integer into a hexadecimal string: the colorhex.
     * @param n Color's tokenId.
     * @return colorhex Color's 6-digit hexadecimal representation.
     */
    function getColorhex(uint n) public pure returns (string memory) {
        require(n < 16777216, "too big number");
        bytes memory colorhex = new bytes(6); // color-hexadecimal number is one size
        for (uint i = 1; i < 7; ++i) {
            // color-hexadecimal number is constructed, but starting with lowest numeral
            colorhex[6 - i] = _HEX_SYMBOLS[n % (1 << 4)]; // convert the decimal number's 4 rightmost bits into a hexadecimal numeral, then store in correct place
            n >>= 4; // shift the decimal number rightwards by 4 bits, allowing subsequent conversions of decimal number's 4 rightmost bits to a hexadecimal numeral
        }
        assert(colorhex.length == 6);
        return string(colorhex); // color-hexadecimal number is actually a string, which is a stringing together of the correctly placed hexadecimal numerals
    }

    /**
     * @notice Retrieves a token's URI.
     * @dev Makes the JSON, which contains the name, description, and picture (an SVG), all on-chain.
     * @param tokenId Color's tokenId.
     * @return Token's metadata, which includes a SVG-coded picture.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(tokenId < 16777216, "too big number");
        string memory name = _getName(tokenId);
        string memory colorhex = getColorhex(tokenId);
        string[7] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="50%" y="16" text-anchor="middle" rotate="180" style="fill: black; font-size: 35px;">&#9814;</text><text x="50%" y="320" text-anchor="middle" class="base">';
        parts[1] = name;
        parts[
            2
        ] = '</text><text x="50%" y="337" text-anchor="middle" class="base">#';
        parts[3] = colorhex;
        parts[
            4
        ] = '</text><rect x="50" y="50" width="250" height="250" fill="#';
        parts[5] = colorhex;
        parts[6] = '" /></svg>';
        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6]
            )
        );
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "Visit color.rockopera.eth for more.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return output;
    }
}
