# Charlie Coin Plus (CCP)

<p align="center">
  <img src="https://i.czl.net/b2/img/2025/09/68bc2ff2eb42f.jpeg" alt="Charlie Coin Plus Logo" width="450" height="450"/>
</p>

**Charlie Coin Plus (CCP)** 是一款基于 **币安智能链 (BSC)** 的交易型加密货币，  
是 **Charlie Coin** 的升级版本，由 [Charlie Kuo (郭权锐)](https://github.com/Charlie-May9) 开发。  

✅ 官网: [Charlie Coin Plus 官方网站](https://charlie-may9.github.io/Charlie-Coin-Plus)  
✅ PancakeSwap: [点击交易 CCP](https://pancakeswap.finance/swap?outputCurrency=0x1E853C470Fa3d5234D9Ba7204EE04BEA27c9eee9&chainId=56)  
✅ BscScan: [查看合约](https://bscscan.com/token/0x1E853C470Fa3d5234D9Ba7204EE04BEA27c9eee9)  

---

## 📖 项目简介
- **代币名称**: Charlie Coin Plus  
- **代币符号**: CCP  
- **区块链平台**: Binance Smart Chain (BSC)  
- **合约标准**: BEP-20  
- **合约地址**: [`0x1E853C470Fa3d5234D9Ba7204EE04BEA27c9eee9`](https://bscscan.com/token/0x1E853C470Fa3d5234D9Ba7204EE04BEA27c9eee9)  
- **初始供应量**: 1,000,000 CCP（全部由合约部署者铸造）

---

## 🎯 设计理念
Charlie Coin Plus 致力于成为一款 **安全可靠、低成本、高速** 的交易型加密货币。  
它继承了 Charlie Coin 的纪念意义，同时增加了交易功能，兼具 **传承与创新**。

---

## 🚀 核心特性
- ⚡ **高效交易**：基于 BSC 网络，确认速度快，手续费低  
- 🔒 **安全可靠**：合约采用 OpenZeppelin ERC20 + Ownable 库，多重安全优化  
- 🏦 **交易所上市**：已在 PancakeSwap 去中心化交易所上线  
- 🌍 **BSC 生态**：享受 Binance Smart Chain 的高效与低成本  

---

### 核心机制
- **交易税系统**: 默认 1%，最高不超过 10%，自动发送至指定接收地址  
- **白名单机制**: 白名单内地址可免除交易税  
- **增发限制**:  
  - 每次最多增发 200 枚代币  
  - 每月最多增发 2 次  
- **权限管理**:  
  - 修改税率、白名单管理、增发操作仅限合约所有者  

### 合约
```solidity
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


