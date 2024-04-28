pragma solidity ^0.8;

contract SuappSequencedBase {
    // SUAPP address allowed to sequence.
    address public suappKey;

    // SUAPP contract admin.
    address public suappAdmin;

    // Event emitted when the owner is changed.
    event SuappAdminChanged(
        address indexed _oldAdmin,
        address indexed _newAdmin
    );
    // Event emitted when the SUAPP address is changed.
    event SuappKeyChanged(
        address indexed _oldSuappKey,
        address indexed _newSuappKey
    );

    // Errors for various contract exceptions.
    error OnlySuappAdmin();
    error OnlySuappKey();
    error WrongSuappKey();
    error ZeroAddress();

    /**
     * @dev Ensures the caller is the specified SUAPP.
     */
    modifier onlySuappKey() {
        if (msg.sender != suappKey) revert OnlySuappKey();
        _;
    }

    /**
     * @dev Ensures the caller is the owner of the contract.
     */
    modifier onlySuappAdmin() {
        if (msg.sender != suappAdmin) revert OnlySuappAdmin();
        _;
    }

    /**
     * @dev Initializes the contract setting the initial SUAPP and the owner to the sender.
     */
    constructor() {
        suappAdmin = msg.sender;
    }

    /**
     * @notice Allows the suapp admin to change the suapp admin.
     * @param newSuappAdmin The address of the new owner.
     */
    function setSuappAdmin(address newSuappAdmin) public onlySuappAdmin {
        if (newSuappAdmin == address(0)) revert ZeroAddress();
        address oldSuappAdmin = suappAdmin;
        suappAdmin = newSuappAdmin;
        emit SuappAdminChanged(oldSuappAdmin, suappAdmin);
    }

    /**
     * @notice Allows the admin to change the suapp public key
     * @param newSuappKey The new suapp's stored public key
     */
    function setSuappKey(address newSuappKey) public onlySuappAdmin {
        if (newSuappKey == address(0)) revert ZeroAddress();
        address oldSuappKey = newSuappKey;
        suappKey = newSuappKey;
        emit SuappKeyChanged(oldSuappKey, suappKey);
    }
}
