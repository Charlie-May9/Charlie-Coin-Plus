// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CharlieCoinPlus is ERC20, Ownable {
    // 税务系统变量
    uint256 public taxRate = 1; // 1%的交易税
    address public taxRecipient; // 税务接收地址
    mapping(address => bool) public isWhitelisted; // 免税地址白名单
    
    // 增发限制系统
    uint256 public constant MINT_LIMIT_PER_TX = 200 * 1e18; // 每次增发上限200个代币（含精度）
    uint256 public constant MINT_LIMIT_PER_MONTH = 2; // 每月最多增发次数
    uint256 public lastMintResetTime; // 上次重置增发计数的时间
    uint256 public mintCountThisMonth; // 本月已增发次数
    
    // 事件
    event Whitelisted(address indexed account, bool status); // 白名单变更事件
    event TaxCollected(address indexed from, uint256 amount); // 税收事件
    event TaxRateChanged(uint256 newRate); // 税率变更事件
    event TaxRecipientChanged(address newRecipient); // 税收接收方变更事件
    event AdditionalMint(address indexed recipient, uint256 amount); // 增发事件

    constructor() ERC20("Charlie Coin Plus", "CCP") Ownable(msg.sender) {
        // 初始铸造100万个代币给部署者
        _mint(msg.sender, 1000000 * 10 ** decimals());
        // 设置初始税务接收地址
        taxRecipient = msg.sender;
        // 初始化增发时间计数器
        lastMintResetTime = block.timestamp;
    }

    // 设置税务接收地址（仅所有者）
    function setTaxRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Cannot set to zero address");
        taxRecipient = _recipient;
        emit TaxRecipientChanged(_recipient);
    }

    // 设置税率（仅所有者）
    function setTaxRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 10, "Tax rate cannot exceed 10%");
        taxRate = _newRate;
        emit TaxRateChanged(_newRate);
    }

    // 添加地址到白名单（仅所有者）
    function addToWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = true;
        emit Whitelisted(_address, true);
    }

    // 从白名单移除地址（仅所有者）
    function removeFromWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = false;
        emit Whitelisted(_address, false);
    }

    // 有限制的增发功能（仅所有者）
    function mintAdditionalTokens(uint256 amount) external onlyOwner {
        // 检查是否需要重置增发计数器（超过30天）
        if (block.timestamp > lastMintResetTime + 30 days) {
            mintCountThisMonth = 0;
            lastMintResetTime = block.timestamp;
        }
        
        // 验证增发限制
        require(mintCountThisMonth < MINT_LIMIT_PER_MONTH, "Monthly mint limit reached");
        require(amount <= MINT_LIMIT_PER_TX, "Exceeds per-transaction mint limit");
        
        // 更新计数器并执行增发
        mintCountThisMonth += 1;
        _mint(msg.sender, amount);
        emit AdditionalMint(msg.sender, amount);
    }

    // 覆盖transfer函数（含税收逻辑）
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (shouldApplyTax(msg.sender)) {
            // 计算税收和净转账金额
            uint256 taxAmount = (amount * taxRate) / 100;
            uint256 amountAfterTax = amount - taxAmount;
            
            // 转移税款到接收地址
            super._transfer(msg.sender, taxRecipient, taxAmount);
            emit TaxCollected(msg.sender, taxAmount);
            
            // 转移剩余金额到接收方
            super._transfer(msg.sender, recipient, amountAfterTax);
            return true;
        } else {
            // 白名单地址免税转账
            return super.transfer(recipient, amount);
        }
    }

    // 覆盖transferFrom函数（含税收逻辑）
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (shouldApplyTax(sender)) {
            // 计算税收和净转账金额
            uint256 taxAmount = (amount * taxRate) / 100;
            uint256 amountAfterTax = amount - taxAmount;
            
            // 扣除授权额度（安全修复）
            _spendAllowance(sender, _msgSender(), amount);
            
            // 转移税款到接收地址
            super._transfer(sender, taxRecipient, taxAmount);
            emit TaxCollected(sender, taxAmount);
            
            // 转移剩余金额到接收方
            super._transfer(sender, recipient, amountAfterTax);
            return true;
        } else {
            // 白名单地址免税转账
            return super.transferFrom(sender, recipient, amount);
        }
    }

    // 内部辅助函数：检查是否应征税
    function shouldApplyTax(address sender) private view returns (bool) {
        // 仅对非白名单地址、有效接收地址且税率>0时征税
        return !isWhitelisted[sender] && 
               taxRecipient != address(0) && 
               taxRate > 0;
    }
}

