
COMPLETE GUIDE: CodeIsLaw Escrow Smart Contract
================================================

STEP 1: PROJECT SETUP
---------------------

1. Create project directory and install dependencies:

cd ~
mkdir -p Documents/Solidity
cd Documents/Solidity
rm -rf escrow
mkdir escrow
cd escrow
npm init -y
npm install --save-dev hardhat@^2.22.0 @nomicfoundation/hardhat-toolbox@^5.0.0
npm install @openzeppelin/contracts

2. Initialize Hardhat:

npx hardhat init

   - Select: "Create a JavaScript project"
   - Press Enter for all defaults
   - Say "Y" to install dependencies


STEP 2: CREATE SMART CONTRACT
------------------------------

3. Remove example files:

rm contracts/Lock.sol
rm test/Lock.js
rm -f ignition/modules/Lock.js

4. Create the TrustlessEscrow contract:

nano contracts/TrustlessEscrow.sol

Paste the complete Solidity code (TrustlessEscrow.sol from the guide), then:
   - Press Ctrl+X
   - Press Y
   - Press Enter


STEP 3: CREATE TEST FILE
-------------------------

5. Create test file:

nano test/TrustlessEscrow.test.js

Paste the complete test code (TrustlessEscrow.test.js from the guide), then:
   - Press Ctrl+X
   - Press Y
   - Press Enter


STEP 4: UPDATE CONFIG
----------------------

6. Update hardhat.config.js:

nano hardhat.config.js

Replace everything with:

require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};

Save: Ctrl+X, Y, Enter


STEP 5: TEST THE CONTRACT
--------------------------

7. Compile and test:

npx hardhat compile
npx hardhat test

You should see 18 passing tests.


STEP 6: CREATE DEPLOYMENT SCRIPT
---------------------------------

8. Create deploy script:

nano scripts/deploy.js

Paste this code:

const hre = require("hardhat");

async function main() {
  console.log("Deploying TrustlessEscrow...");

  const [deployer, client, freelancer, arbiter] = await hre.ethers.getSigners();

  console.log("Deploying with accounts:");
  console.log("Client:", client.address);
  console.log("Freelancer:", freelancer.address);
  console.log("Arbiter:", arbiter.address);

  const TrustlessEscrow = await hre.ethers.getContractFactory("TrustlessEscrow");
  const escrow = await TrustlessEscrow.deploy(
    client.address,
    freelancer.address,
    arbiter.address
  );

  await escrow.waitForDeployment();
  const address = await escrow.getAddress();

  console.log("Contract deployed to:", address);
  console.log("COPY THIS ADDRESS FOR THE UI:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

Save: Ctrl+X, Y, Enter


STEP 7: CREATE FRONTEND
------------------------

9. Create public folder and index.html:

mkdir public
nano public/index.html

Paste the complete HTML code from the guide.

IMPORTANT: Find line 217 that says:
const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS_HERE";

Leave it as is for now. We'll update it after deployment.

Save: Ctrl+X, Y, Enter


STEP 8: START LOCAL BLOCKCHAIN
-------------------------------

10. Open TERMINAL 1 and run:

cd ~/Documents/Solidity/escrow
npx hardhat node

LEAVE THIS RUNNING. You'll see 20 accounts with addresses and private keys.

COPY ONE PRIVATE KEY - it looks like:
0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80


STEP 9: DEPLOY CONTRACT
------------------------

11. Open TERMINAL 2 and run:

cd ~/Documents/Solidity/escrow
npx hardhat run scripts/deploy.js --network localhost

COPY THE CONTRACT ADDRESS that appears (starts with 0x...)


12. Update the contract address in HTML:

nano public/index.html

Find line 217:
const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS_HERE";

Replace YOUR_CONTRACT_ADDRESS_HERE with the address you copied (keep the quotes).

Save: Ctrl+X, Y, Enter


STEP 10: START WEB SERVER
--------------------------

13. Open TERMINAL 3 and run:

cd ~/Documents/Solidity/escrow
npx http-server public -p 8080

If you get "command not found", run this first:
npm install -g http-server

Then run the http-server command again.

LEAVE THIS RUNNING.


STEP 11: SETUP METAMASK
------------------------

14. Install MetaMask browser extension:
   - Go to https://metamask.io/download/
   - Install for your browser
   - Create a new wallet (you can skip backup for testing)
   - Set a password

15. Add Hardhat Local network to MetaMask:
   - Click the network dropdown (top of MetaMask)
   - Click "Add Network" or "Add a custom network"
   - Fill in:
     Network Name: Hardhat Local
     RPC URL: http://127.0.0.1:8545
     Chain ID: 31337
     Currency Symbol: ETH
   - Click Save

16. Import a test account:
   - In MetaMask, click the account icon (top right)
   - Click "Import Account"
   - Paste the PRIVATE KEY you copied from Terminal 1 (Step 10)
   - Click Import
   - You should see 10000 ETH


STEP 12: USE THE APPLICATION
-----------------------------

17. Open browser and go to:

http://localhost:8080

18. Click "Connect MetaMask"
   - Approve the connection

19. You should see:
   - Your wallet address
   - Contract details
   - State machine showing "CREATED"

20. Test the workflow:

   a) DEPOSIT FUNDS (Client):
      - Enter 0.1 in the amount field
      - Click "Deposit Funds"
      - Approve transaction in MetaMask
      - State changes to "FUNDED"

   b) COMPLETE WORK (Freelancer):
      - In MetaMask, import another account (use another private key from Terminal 1)
      - Refresh the page and reconnect
      - Click "Mark Work Complete"
      - Approve transaction
      - State changes to "WORK_DONE"

   c) APPROVE PAYMENT (Client):
      - Switch back to the first account in MetaMask
      - Refresh and reconnect
      - Click "Approve & Pay"
      - Approve transaction
      - State changes to "PAID"
      - Freelancer receives the funds

21. Check the event log at the bottom to see all on-chain activity


TROUBLESHOOTING
---------------

Problem: "Insufficient funds" error
Solution: Make sure you imported an account from Terminal 1 (Hardhat node)
          and that MetaMask is on "Hardhat Local" network

Problem: "Cannot connect to network"
Solution: Make sure Terminal 1 (npx hardhat node) is still running

Problem: Contract not found
Solution: Redeploy the contract (Step 11) and update the address in index.html

Problem: MetaMask shows 0 ETH
Solution: Check you're on "Hardhat Local" network (not Ethereum Mainnet)
          Import an account using a private key from Terminal 1


RUNNING THE PROJECT AGAIN
--------------------------

If you close everything and want to run again:

Terminal 1:
cd ~/Documents/Solidity/escrow
npx hardhat node

Terminal 2:
cd ~/Documents/Solidity/escrow
npx hardhat run scripts/deploy.js --network localhost
(Update contract address in index.html)

Terminal 3:
cd ~/Documents/Solidity/escrow
npx http-server public -p 8080

Then:
- Import fresh account from Terminal 1
- Go to http://localhost:8080
- Test the escrow workflow


UNDERSTANDING THE 5 CONCEPTS
-----------------------------

CONCEPT 1: Immutable State Machine
- Watch the state boxes change color: CREATED -> FUNDED -> WORK_DONE -> PAID
- Each state transition is permanent and recorded on-chain

CONCEPT 2: Self-Executing Agreements
- Code automatically holds and releases funds
- No bank or intermediary needed
- Time-based automation (auto-release after 7 days)

CONCEPT 3: Cryptographic Proof & Verification
- Check the Event Log section to see all transactions
- Every action is permanently recorded with block numbers and timestamps
- Anyone can verify what happened

CONCEPT 4: Trustless Interaction
- Client doesn't need to trust freelancer (funds locked in contract)
- Freelancer doesn't need to trust client (guaranteed payment after dispute period)
- Arbiter can resolve disputes neutrally

CONCEPT 5: Gas Economics
- Every action costs gas (shown after each transaction)
- Creates "skin in the game" for participants
- Prevents spam and malicious behavior


COMPLETE - YOU'RE DONE!
-----------------------

You've successfully built and deployed a trustless escrow smart contract!
