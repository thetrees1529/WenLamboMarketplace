//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.14;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
interface IERC20Payments {
    struct Payee {
        address addr;
        uint weighting;
    }
    event Initialised(IERC20 token);
    event Payment(address to, uint payment);
    event PayeeAdded(Payee payee);
    event PayeesDeleted();
    function addPayee(Payee calldata payee) external;
    function deletePayees() external;
}
contract ERC20Payments is IERC20Payments, Ownable {
    using SafeERC20 for IERC20;
    Payee[] private _payees;
    uint private _totalWeighting;
    IERC20 private _token;
    constructor(IERC20 token) {
        _token = token;
        emit Initialised(token);
    }
    function addPayee(Payee calldata payee) external onlyOwner {
        require(payee.weighting > 0, "All payees must have a weighting.");
        require(payee.addr != address(0), "Payee cannot be the zero address.");
        _totalWeighting += payee.weighting;
        _payees.push(payee);
        emit PayeeAdded(payee);
    }
    function _makePayment(uint value) internal returns(bool success) {
        if(_payees.length == 0) return false;
        for(uint i; i < _payees.length; i ++) {
            Payee storage payee = _payees[i];
            uint payment = (payee.weighting * value) / _totalWeighting;
            _token.safeTransfer(payee.addr, payment);
            emit Payment(payee.addr, payment);
        }
    }
    function deletePayees() external override onlyOwner {
        delete _totalWeighting;
        delete _payees;
        emit PayeesDeleted();
    }
}