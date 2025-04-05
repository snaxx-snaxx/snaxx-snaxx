- 👋 Hi,
- 2023-I’m building a SFT trading card game (TCG)
- 2023 I’m currently exploring EVM and solidity
- 2023 I’m looking to collaborate on ...peer to peer TCG game platform
- 2024- update- deploy tag team crypto agents in python
- 2024- deploy ERC3525 as agent smart wallet
- 2024- update- launch smart contract digital container for agents
- 2025- built dapp for agent social engagement and trade competions
- 2025- deploy utility token for interacting with dapp
- 2025- ready to deploy $FIGHT CLUB AI social [Uploading Dual_Auto_AI_Agent_Build_0001.py…]()

- 📫- pickformethen@yahoo
- "X" @snaxx-snaxx
-
- [Uploading 3525_agent_2.py…]()
- #-----------script 2 of 2-------------------------------
# file ERC3525_AGENT

#!/usr/bin/env python3
import os
import time
import json
import logging
import argparse
from decimal import Decimal
from dotenv import load_dotenv
from web3 import Web3
from cdp import Cdp, Wallet

# Setup logging
logging.basicConfig(
    filename="erc3525_agent.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger()

def setup_env():
    load_dotenv()
    rpc_url = os.getenv("RPC_URL")
    erc3525_address = os.getenv("ERC3525_CONTRACT_ADDRESS")
    api_key_name = os.getenv("CDP_API_KEY_NAME")
    api_key_private = os.getenv("CDP_API_KEY_PRIVATE")
    private_key = os.getenv("PRIVATE_KEY")
    if not all([rpc_url, erc3525_address, api_key_name, api_key_private, private_key]):
        logger.error("One or more required environment variables are missing.")
        raise EnvironmentError("Missing environment variables.")
    return rpc_url, erc3525_address, api_key_name, api_key_private, private_key

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--paper', action='store_true', help='Enable paper trading mode (simulate transactions)')
    parser.add_argument('--strategy', type=str, default='default', help='Select strategy mode (default, alternate)')
    args = parser.parse_args()
    return args.paper, args.strategy

# Define wallet file location.
WALLET_FILE = os.path.join(os.path.dirname(__file__), "wallet_seed.json")

def load_or_create_wallet(api_key_name, api_key_private):
    Cdp.configure(api_key_name, api_key_private)
    if os.path.exists(WALLET_FILE):
        try:
            with open(WALLET_FILE, "r") as f:
                wallet_data = json.load(f)
            wallet_id = wallet_data.get("id")
            if not wallet_id:
                raise ValueError("Wallet ID not found in seed file.")
            wallet = Wallet.fetch(wallet_id)
            wallet.load_seed_from_file(WALLET_FILE)
            logger.info("Existing wallet loaded successfully.")
            return wallet
        except Exception as e:
            logger.error(f"Error loading wallet: {e}. Removing corrupt wallet file.")
            os.remove(WALLET_FILE)
    try:
        wallet = Wallet.create("base-mainnet")
        wallet.save_seed_to_file(WALLET_FILE, encrypt=True)
        logger.info(f"New wallet created with id {wallet.id}")
        return wallet
    except Exception as e:
        logger.error(f"Failed to create wallet: {e}")
        raise

def init_web3(rpc_url):
    web3 = Web3(Web3.HTTPProvider(rpc_url))
    if not web3.isConnected():
        logger.error("Error connecting to Ethereum node.")
        raise ConnectionError("Web3 provider connection failed.")
    logger.info("Connected to Ethereum node.")
    return web3

def load_contract(web3, contract_address):
    abi_file = os.path.join(os.path.dirname(__file__), "ERC3525_ABI.json")
    try:
        with open(abi_file, "r") as f:
            contract_abi = json.load(f)
    except Exception as e:
        logger.error(f"Failed to load contract ABI: {e}")
        raise
    try:
        contract = web3.eth.contract(
            address=Web3.toChecksumAddress(contract_address),
            abi=contract_abi
        )
        logger.info("ERC3525 contract loaded successfully.")
        return contract
    except Exception as e:
        logger.error(f"Failed to initialize contract: {e}")
        raise

def get_account(web3, private_key, wallet):
    try:
        account = web3.eth.account.privateKeyToAccount(private_key)
    except Exception as e:
        logger.error(f"Failed to create account from PRIVATE_KEY: {e}")
        if hasattr(wallet, 'private_key'):
            account = web3.eth.account.privateKeyToAccount(wallet.private_key)
        else:
            raise
    web3.eth.default_account = account.address
    logger.info(f"Using account address: {account.address}")
    return account

def simple_strategy(web3, contract, account, paper_mode):
    slot = 1
    threshold = Decimal("50")
    try:
        slot_balance = contract.functions.slotBalance(slot).call()
        logger.info(f"Current balance for slot {slot}: {slot_balance}")
    except Exception as e:
        logger.error(f"Error reading slot balance: {e}")
        slot_balance = 0
    if Decimal(slot_balance) < threshold:
        logger.info("Balance below threshold. Proceeding to mint additional tokens.")
        mint_value = threshold - Decimal(slot_balance)
        if paper_mode:
            logger.info(f"(Paper Trade) Simulate minting {mint_value} tokens in slot {slot}.")
        else:
            try:
                txn = contract.functions._mint(account.address, slot, int(mint_value)).buildTransaction({
                    'from': account.address,
                    'nonce': web3.eth.getTransactionCount(account.address),
                    'gas': 300000,
                    'gasPrice': web3.toWei('5', 'gwei')
                })
                signed_txn = web3.eth.account.signTransaction(txn, private_key=account.privateKey)
                tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
                logger.info(f"Mint transaction sent, tx hash: {web3.toHex(tx_hash)}")
            except Exception as e:
                logger.error(f"Error sending mint transaction: {e}", exc_info=True)
    else:
        logger.info("Balance meets threshold. No minting necessary.")

def alternate_strategy(web3, contract, account, paper_mode):
    slot = 2
    threshold = Decimal("100")
    try:
        slot_balance = contract.functions.slotBalance(slot).call()
        logger.info(f"(Alternate) Current balance for slot {slot}: {slot_balance}")
    except Exception as e:
        logger.error(f"Error reading slot balance for alternate strategy: {e}")
        slot_balance = 0
    if Decimal(slot_balance) < threshold:
        logger.info("(Alternate) Balance below threshold. Minting additional tokens.")
        mint_value = threshold - Decimal(slot_balance)
        if paper_mode:
            logger.info(f"(Paper Trade) (Alternate) Simulate minting {mint_value} tokens in slot {slot}.")
        else:
            try:
                txn = contract.functions._mint(account.address, slot, int(mint_value)).buildTransaction({
                    'from': account.address,
                    'nonce': web3.eth.getTransactionCount(account.address),
                    'gas': 300000,
                    'gasPrice': web3.toWei('5', 'gwei')
                })
                signed_txn = web3.eth.account.signTransaction(txn, private_key=account.privateKey)
                tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
                logger.info(f"(Alternate) Mint transaction sent, tx hash: {web3.toHex(tx_hash)}")
            except Exception as e:
                logger.error(f"Error sending mint transaction in alternate strategy: {e}", exc_info=True)
    else:
        logger.info("(Alternate) Balance meets threshold. No action required.")

def main_loop(web3, contract, account, paper_mode, strategy_mode):
    while True:
        try:
            if strategy_mode.lower() == 'default':
                simple_strategy(web3, contract, account, paper_mode)
            elif strategy_mode.lower() == 'alternate':
                alternate_strategy(web3, contract, account, paper_mode)
            else:
                logger.warning("Unknown strategy mode specified. Defaulting to simple strategy.")
                simple_strategy(web3, contract, account, paper_mode)
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
        time.sleep(10)  # Adjust the interval as needed

def main():
    try:
        paper_mode, strategy_mode = parse_args()
        rpc_url, erc3525_address, api_key_name, api_key_private, private_key = setup_env()
        web3 = init_web3(rpc_url)
        wallet = load_or_create_wallet(api_key_name, api_key_private)
        account = get_account(web3, private_key, wallet)
        contract = load_contract(web3, erc3525_address)
        logger.info("Starting main loop for ERC3525 agent.")
        main_loop(web3, contract, account, paper_mode, strategy_mode)
    except Exception as e:
        logger.critical(f"Critical error encountered: {e}", exc_info=True)
        exit(1)

if __name__ == "__main__":
    main()
	#-----------agent file 1 of 2 -------------------
    #!/usr/bin/env python3
import os
import time
import json
import logging
import argparse
from decimal import Decimal
from dotenv import load_dotenv
from web3 import Web3
from cdp import Cdp, Wallet

# Setup logging
logging.basicConfig(
    filename="erc3525_agent.log",
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger()

def setup_env():
    load_dotenv()
    rpc_url = os.getenv("RPC_URL")
    erc3525_address = os.getenv("ERC3525_CONTRACT_ADDRESS")
    api_key_name = os.getenv("CDP_API_KEY_NAME")
    api_key_private = os.getenv("CDP_API_KEY_PRIVATE")
    private_key = os.getenv("PRIVATE_KEY")
    if not all([rpc_url, erc3525_address, api_key_name, api_key_private, private_key]):
        logger.error("One or more required environment variables are missing.")
        raise EnvironmentError("Missing environment variables.")
    return rpc_url, erc3525_address, api_key_name, api_key_private, private_key

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--paper', action='store_true', help='Enable paper trading mode (simulate transactions)')
    parser.add_argument('--strategy', type=str, default='default', help='Select strategy mode (default, alternate)')
    args = parser.parse_args()
    return args.paper, args.strategy

# Define wallet file location.
WALLET_FILE = os.path.join(os.path.dirname(__file__), "wallet_seed.json")

def load_or_create_wallet(api_key_name, api_key_private):
    Cdp.configure(api_key_name, api_key_private)
    if os.path.exists(WALLET_FILE):
        try:
            with open(WALLET_FILE, "r") as f:
                wallet_data = json.load(f)
            wallet_id = wallet_data.get("id")
            if not wallet_id:
                raise ValueError("Wallet ID not found in seed file.")
            wallet = Wallet.fetch(wallet_id)
            wallet.load_seed_from_file(WALLET_FILE)
            logger.info("Existing wallet loaded successfully.")
            return wallet
        except Exception as e:
            logger.error(f"Error loading wallet: {e}. Removing corrupt wallet file.")
            os.remove(WALLET_FILE)
    try:
        wallet = Wallet.create("base-mainnet")
        wallet.save_seed_to_file(WALLET_FILE, encrypt=True)
        logger.info(f"New wallet created with id {wallet.id}")
        return wallet
    except Exception as e:
        logger.error(f"Failed to create wallet: {e}")
        raise

def init_web3(rpc_url):
    web3 = Web3(Web3.HTTPProvider(rpc_url))
    if not web3.isConnected():
        logger.error("Error connecting to Ethereum node.")
        raise ConnectionError("Web3 provider connection failed.")
    logger.info("Connected to Ethereum node.")
    return web3

def load_contract(web3, contract_address):
    abi_file = os.path.join(os.path.dirname(__file__), "ERC3525_ABI.json")
    try:
        with open(abi_file, "r") as f:
            contract_abi = json.load(f)
    except Exception as e:
        logger.error(f"Failed to load contract ABI: {e}")
        raise
    try:
        contract = web3.eth.contract(
            address=Web3.toChecksumAddress(contract_address),
            abi=contract_abi
        )
        logger.info("ERC3525 contract loaded successfully.")
        return contract
    except Exception as e:
        logger.error(f"Failed to initialize contract: {e}")
        raise

def get_account(web3, private_key, wallet):
    try:
        account = web3.eth.account.privateKeyToAccount(private_key)
    except Exception as e:
        logger.error(f"Failed to create account from PRIVATE_KEY: {e}")
        if hasattr(wallet, 'private_key'):
            account = web3.eth.account.privateKeyToAccount(wallet.private_key)
        else:
            raise
    web3.eth.default_account = account.address
    logger.info(f"Using account address: {account.address}")
    return account

def simple_strategy(web3, contract, account, paper_mode):
    slot = 1
    threshold = Decimal("50")
    try:
        slot_balance = contract.functions.slotBalance(slot).call()
        logger.info(f"Current balance for slot {slot}: {slot_balance}")
    except Exception as e:
        logger.error(f"Error reading slot balance: {e}")
        slot_balance = 0
    if Decimal(slot_balance) < threshold:
        logger.info("Balance below threshold. Proceeding to mint additional tokens.")
        mint_value = threshold - Decimal(slot_balance)
        if paper_mode:
            logger.info(f"(Paper Trade) Simulate minting {mint_value} tokens in slot {slot}.")
        else:
            try:
                txn = contract.functions._mint(account.address, slot, int(mint_value)).buildTransaction({
                    'from': account.address,
                    'nonce': web3.eth.getTransactionCount(account.address),
                    'gas': 300000,
                    'gasPrice': web3.toWei('5', 'gwei')
                })
                signed_txn = web3.eth.account.signTransaction(txn, private_key=account.privateKey)
                tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
                logger.info(f"Mint transaction sent, tx hash: {web3.toHex(tx_hash)}")
            except Exception as e:
                logger.error(f"Error sending mint transaction: {e}", exc_info=True)
    else:
        logger.info("Balance meets threshold. No minting necessary.")

def alternate_strategy(web3, contract, account, paper_mode):
    slot = 2
    threshold = Decimal("100")
    try:
        slot_balance = contract.functions.slotBalance(slot).call()
        logger.info(f"(Alternate) Current balance for slot {slot}: {slot_balance}")
    except Exception as e:
        logger.error(f"Error reading slot balance for alternate strategy: {e}")
        slot_balance = 0
    if Decimal(slot_balance) < threshold:
        logger.info("(Alternate) Balance below threshold. Minting additional tokens.")
        mint_value = threshold - Decimal(slot_balance)
        if paper_mode:
            logger.info(f"(Paper Trade) (Alternate) Simulate minting {mint_value} tokens in slot {slot}.")
        else:
            try:
                txn = contract.functions._mint(account.address, slot, int(mint_value)).buildTransaction({
                    'from': account.address,
                    'nonce': web3.eth.getTransactionCount(account.address),
                    'gas': 300000,
                    'gasPrice': web3.toWei('5', 'gwei')
                })
                signed_txn = web3.eth.account.signTransaction(txn, private_key=account.privateKey)
                tx_hash = web3.eth.sendRawTransaction(signed_txn.rawTransaction)
                logger.info(f"(Alternate) Mint transaction sent, tx hash: {web3.toHex(tx_hash)}")
            except Exception as e:
                logger.error(f"Error sending mint transaction in alternate strategy: {e}", exc_info=True)
    else:
        logger.info("(Alternate) Balance meets threshold. No action required.")

def main_loop(web3, contract, account, paper_mode, strategy_mode):
    while True:
        try:
            if strategy_mode.lower() == 'default':
                simple_strategy(web3, contract, account, paper_mode)
            elif strategy_mode.lower() == 'alternate':
                alternate_strategy(web3, contract, account, paper_mode)
            else:
                logger.warning("Unknown strategy mode specified. Defaulting to simple strategy.")
                simple_strategy(web3, contract, account, paper_mode)
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
        time.sleep(10)  # Adjust the interval as needed

def main():
    try:
        paper_mode, strategy_mode = parse_args()
        rpc_url, erc3525_address, api_key_name, api_key_private, private_key = setup_env()
        web3 = init_web3(rpc_url)
        wallet = load_or_create_wallet(api_key_name, api_key_private)
        account = get_account(web3, private_key, wallet)[Uploading run_agent_01_0
#run_agent_v01-01 

import datetime
import uuid

# Global controls
HARD_STOP = False
SOFT_STOP = False
VIX_HOLD_THRESHOLD = 25.0

exported_data = {
    "financial": [],
    "metrics": [],
    "strategies": []
}

class Wallet:
    def __init__(self, wallet_id, initial_balance=0.0):
        self.id = wallet_id
        self.initial_balance = initial_balance
        self.balance = initial_balance

    def deposit(self, amount):
        self.balance += amount

    def withdraw(self, amount):
        self.balance -= amount
        if self.balance < 0:
            print(f"Warning: Wallet {self.id} balance went negative.")

    def __repr__(self):
        return f"Wallet(ID={self.id}, balance={self.balance:.2f})"

class TradingAgent:
    def __init__(self, agent_name, agent_id, strategy_params, wallet: Wallet, target_profit=0.0):
        self.name = agent_name
        self.id = agent_id
        self.strategy_params = strategy_params
        self.wallet = wallet
        self.target_profit = target_profit
        self.strategy_detail_str = f"[EMA {strategy_params.get('fast_EMA')},0,SMA{strategy_params.get('baseline_SMA')}] " \
                                   f"[EMA {strategy_params.get('slow_EMA')},0,SMA{strategy_params.get('baseline_SMA')}]"
        self.position_open = False
        self.position_entry_price = None
        self.position_size = 0.0
        self.position_entry_time = None
        self.position_id = None
        self.total_profit = 0.0
        self.goal_reached = False
        self.trades_won = 0
        self.trades_lost = 0
        self.trades_breakeven = 0
        self.session_id_str = ""
        self.asset_symbol = ""
        self.cycle_index_str = "00"
        self.vix_value_str = "0"

    def _generate_transaction_id(self):
        return str(uuid.uuid4())[:8].upper()

    def evaluate_signals(self, price_data, idx):
        f_EMA = self.strategy_params.get("fast_EMA")
        s_EMA = self.strategy_params.get("slow_EMA")
        base_SMA = self.strategy_params.get("baseline_SMA")
        prices = price_data['price']
        if f'EMA{f_EMA}' not in price_data:
            price_data[f'EMA{f_EMA}'] = [None] * len(prices)
        if f'EMA{s_EMA}' not in price_data:
            price_data[f'EMA{s_EMA}'] = [None] * len(prices)
        if f'SMA{base_SMA}' not in price_data:
            price_data[f'SMA{base_SMA}'] = [None] * len(prices)
        if price_data[f'SMA{base_SMA}'][idx] is None:
            if idx + 1 >= base_SMA:
                window = prices[idx - base_SMA + 1: idx + 1]
                price_data[f'SMA{base_SMA}'][idx] = sum(window) / base_SMA
            else:
                window = prices[:idx + 1]
                price_data[f'SMA{base_SMA}'][idx] = sum(window) / len(window)
        for ema_label, ema_period in [(f'EMA{f_EMA}', f_EMA), (f'EMA{s_EMA}', s_EMA)]:
            if price_data[ema_label][idx] is None:
                if idx == 0 or price_data[ema_label][idx - 1] is None:
                    price_data[ema_label][idx] = prices[idx]
                else:
                    alpha = 2 / (ema_period + 1)
                    prev = price_data[ema_label][idx - 1]
                    price_data[ema_label][idx] = prev + alpha * (prices[idx] - prev)
        ema_fast = price_data[f'EMA{f_EMA}'][idx]
        ema_slow = price_data[f'EMA{s_EMA}'][idx]
        sma_base = price_data[f'SMA{base_SMA}'][idx]
        signal = None
        if not self.position_open:
            if ema_fast > sma_base and ema_slow > sma_base:
                signal = {"action": "BUY", "reason": f"{f_EMA}>{base_SMA}"}
        else:
            if ema_fast < sma_base:
                signal = {"action": "SELL", "reason": f"{f_EMA}<{base_SMA}"}
        return signal

    def execute_trade(self, action, price, timestamp):
        tx_id = self._generate_transaction_id()
        print(f"[{self.id}] Transaction ID: {tx_id} -> {action} at {price:.4f}")
        time_str = timestamp.strftime("%H:%M")
        if action == 'BUY' and not self.position_open:
            self.wallet.withdraw(price)
            self.position_open = True
            self.position_entry_price = price
            self.position_size = 1.0
            self.position_entry_time = timestamp
            self.position_id = tx_id
            log_entry = f"[{self.id}] [EXEC BUY t_{time_str}] [{self.asset_symbol} {price:.2f}]"
        elif action == 'SELL' and self.position_open:
            profit = price - self.position_entry_price
            self.wallet.deposit(price)
            self.total_profit += profit
            if profit > 0:
                self.trades_won += 1
            elif profit < 0:
                self.trades_lost += 1
            else:
                self.trades_breakeven += 1
            self.position_open = False
            self.position_entry_price = None
            self.position_size = 0.0
            self.position_id = None
            log_entry = f"[{self.id}] [EXEC SELL t_{time_str}] [{self.asset_symbol} {price:.2f} [{profit:+.2f}]]"
        else:
            return
        print(log_entry)

    def set_session_info(self, session_id_str, asset_symbol):
        self.session_id_str = session_id_str
        self.asset_symbol = asset_symbol

    def update_cycle_info(self, cycle_index, vix_value):
        self.cycle_index_str = f"{cycle_index:02d}"
        self.vix_value_str = f"{int(vix_value):02d}"
class TradingSession:
    def __init__(self, session_number, agents, asset_symbol, price_data, vix_data=None):
        self.session_number = session_number
        self.session_id_str = f"{session_number:04d}"
        self.agents = agents
        self.asset_symbol = asset_symbol
        self.price_data = price_data
        self.vix_data = vix_data or [0.0] * len(price_data["price"])
        self.start_time = None

    def run(self):
        print(f"\n=== Starting Session {self.session_id_str} ===")
        for agent in self.agents:
            print(f"Session {self.session_id_str}: Agent {agent.name} (ID {agent.id}), Wallet ID {agent.wallet.id}")
            agent.set_session_info(self.session_id_str, self.asset_symbol)
        for i, price in enumerate(self.price_data['price']):
            current_time = self.price_data['time'][i]
            current_vix = self.vix_data[i]
            for agent in self.agents:
                agent.update_cycle_info(i+1, current_vix)
                if current_vix > VIX_HOLD_THRESHOLD:
                    print(f"[{agent.id}] [HOLD VIX>{VIX_HOLD_THRESHOLD} t_{current_time.strftime('%H:%M')}] [{self.asset_symbol} {price:.2f}]")
                    continue
                signal = agent.evaluate_signals(self.price_data, i)
                if signal:
                    action = signal['action']
                    agent.execute_trade(action, price, current_time)
        print(f"=== Session {self.session_id_str} Complete ===")
1.py…]()

        contract = load_contract(web3, erc3525_address)
        logger.info("Starting main loop for ERC3525 agent.")
        main_loop(web3, contract, account, paper_mode, strategy_mode)
    except Exception as e:
        logger.critical(f"Critical error encountered: {e}", exc_info=True)
        exit(1)

if __name__ == "__main__":
    main()



<!---
snaxx-snaxx/snaxx-snaxx is a ✨ special ✨ repository because its `README.md` (this file) appears on your GitHub profile.
You can click the Preview link to take a look at your changes.
--->
