// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library CairoLib {
    /// @dev The Cairo precompile contract's address.
    address constant CAIRO_MESSAGE_PRECOMPILE = 0x0000000000000000000000000000000000075002;
    address constant CAIRO_MULTICALL_PRECOMPILE= 0x0000000000000000000000000000000000075003;
    address constant CAIRO_CALL_PRECOMPILE= 0x0000000000000000000000000000000000075004;

    struct CairoCall {
        uint256 contractAddress;
        uint256 functionSelector;
        uint256[] data;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on Starknet.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return The return data from the Cairo contract function.
    function callCairo(uint256 contractAddress, uint256 functionSelector, uint256[] calldata data) internal returns (bytes memory) {
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_CALL_PRECOMPILE.call(callData);
        require(success, string(abi.encodePacked("CairoLib: cairo call failed with: ", result)));

        return result;
    }

    function callCairo(CairoCall calldata call) internal returns (bytes memory) {
        return callCairo(call.contractAddress, call.functionSelector, call.data);
    }

    function callCairo(uint256 contractAddress, uint256 functionSelector) internal returns (bytes memory) {
        return callCairo(contractAddress, functionSelector);
    }

    function callCairo(uint256 contractAddress, string calldata functionName) internal returns (bytes memory) {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callCairo(contractAddress, functionSelector);
    }

    function callCairo(uint256 contractAddress, string calldata functionName, uint256[] calldata data) internal returns (bytes memory) {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level static call to a Cairo contract deployed on Starknet.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return The return data from the Cairo contract function.
    function staticcallCairo(uint256 contractAddress, uint256 functionSelector, uint256[] calldata data) internal view returns (bytes memory) {
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_CALL_PRECOMPILE.staticcall(callData);
        require(success, string(abi.encodePacked("CairoLib: cairo static call failed with: ", result)));

        return result;
    }

    function staticcallCairo(CairoCall calldata call) internal view returns (bytes memory) {
        return staticcallCairo(call.contractAddress, call.functionSelector, call.data);
    }

    function staticcallCairo(uint256 contractAddress, uint256 functionSelector) internal view returns (bytes memory) {

        return staticcallCairo(contractAddress, functionSelector);
    }

    function staticcallCairo(uint256 contractAddress, string calldata functionName) internal view returns (bytes memory) {

        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return staticcallCairo(contractAddress, functionSelector);
    }

    function staticcallCairo(uint256 contractAddress, string calldata functionName, uint256[] calldata data) internal view returns (bytes memory) {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return staticcallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a multicall to Cairo contracts deployed on Starknet.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param calls The array of CairoCall structs to be executed.
    function multicallCairo(CairoCall[] calldata calls) internal {
        uint256 n_calls = calls.length;
        bytes memory callData = abi.encode(n_calls);
        for (uint32 i = 0; i < n_calls; i++) {
            CairoCall calldata call = calls[i];
            bytes memory encodedCall = abi.encode(
                call.contractAddress,
                call.functionSelector,
                call.data
            );
            callData = bytes.concat(callData, encodedCall);
        }
        (bool success,) = CAIRO_MULTICALL_PRECOMPILE.call(callData);
        require(success, "CairoLib: multicallCairo failed");
    }

    /// @notice Performs a multicall to Cairo contracts deployed on Starknet.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param calls The array of CairoCall structs to be executed.
    function multicallCairoStatic(CairoCall[] calldata calls) internal view {
        uint256 n_calls = calls.length;
        bytes memory callData = abi.encode(n_calls);
        for (uint32 i = 0; i < n_calls; i++) {
            CairoCall calldata call = calls[i];
            bytes memory encodedCall = abi.encode(
                call.contractAddress,
                call.functionSelector,
                call.data
            );
            callData = bytes.concat(callData, encodedCall);
        }
        (bool success,) = CAIRO_MULTICALL_PRECOMPILE.staticcall(callData);
        require(success, "CairoLib: multicallCairoStatic failed");
    }

    /// @notice Performs a low-level call to send a message from the Kakarot to the Ethereum network.
    /// @param payload The payload of the message to send to the Ethereum contract. The same payload will need
    /// to be provided on L1 to consume the message.
    function sendMessageToL1(bytes memory payload) internal {
        (bool success,) = CAIRO_MESSAGE_PRECOMPILE.call(payload);
        require(success, "CairoLib: sendMessageToL1 failed");
    }

    /// @notice Converts a Cairo ByteArray to a string
    /// @dev A ByteArray is represented as:
    /**
     * pub struct ByteArray {
     *    full_words_len: felt252,
     *    full_words: [<bytes31>],
     *    pending_word: felt252,
     *    pending_word_len: usize,
     *  }
     *  where `full_words` is an array of 31-byte packed words, and `pending_word` word of size `pending_word_len`.
     *  Note that those full words are 32 bytes long, but only 31 bytes are used.
     */
    /// @param data The Cairo representation of the ByteArray serialized to bytes.
    function byteArrayToString(bytes memory data) internal pure returns (string memory) {
        require(data.length >= 96, "Invalid byte array length");

        uint256 fullWordsLength;
        uint256 fullWordsPtr;
        uint256 pendingWord;
        uint256 pendingWordLen;

        assembly {
            fullWordsLength := mload(add(data, 32))
            let fullWordsByteLength := mul(fullWordsLength, 32)
            fullWordsPtr := add(data, 64)
            let pendingWordPtr := add(fullWordsPtr, fullWordsByteLength)
            pendingWord := mload(pendingWordPtr)
            pendingWordLen := mload(add(pendingWordPtr, 32))
        }

        require(pendingWordLen <= 31, "Invalid pending word length");

        uint256 totalLength = fullWordsLength * 31 + pendingWordLen;
        bytes memory result = new bytes(totalLength);
        uint256 resultPtr;

        assembly {
            resultPtr := add(result, 32)
            // Copy full words. Because of the Cairo -> Solidity conversion,
            // each full word is 32 bytes long, but contains 31 bytes of information.
            for { let i := 0 } lt(i, fullWordsLength) { i := add(i, 1) } {
                let word := mload(fullWordsPtr)
                let storedWord := shl(8, word)
                mstore(resultPtr, storedWord)
                resultPtr := add(resultPtr, 31)
                fullWordsPtr := add(fullWordsPtr, 32)
            }
            // Copy pending word
            if iszero(eq(pendingWordLen, 0)) { mstore(resultPtr, shl(mul(sub(32, pendingWordLen), 8), pendingWord)) }
        }

        return string(result);
    }
}
