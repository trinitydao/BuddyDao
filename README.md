# BuddyDao

#### BuddyDao Contracts

##### Bnb  Test Chain:
1.Contracts Address:  
 - BuddyDaoToken address: 0x6d9cAFb986a7E06B1B8749deB2051d4A9F1c725F
 - BUSD Test Address: 0x977A9F4945D664756F25fEd969745C0eA13d1354
 - New BUSD Test Address: 0x98c558cfb320500da05392bE65d1dBf84369C70e

2.Deploy 
 - npx hardhat run scripts/deploy.js  

3.Vrify Contract Address:
 - npx hardhat verify 0x8857c609Bc02dA0a86A6cFbc307767844026Edba "100000000000000000" "0x679629069bd69eEe0E6f1c85e1DE927FbF8dab8f" "500000000000000000"

4.Test Contracts:
 - npx hardhat test tests/buddydao.test.js


#### Operation steps
1. Lend and Borrower authorize the use of BUSD for Buddy Dao contract addresses;
2. Lend can add and remove trust
3. Borrower can withdraw or pay it


#### Cautions (approve tokens)
1. Lender trusts need to authorize the trust token to the buddyDao contract before, otherwise the borrower can't get the loan;
2. The borrower must also authorize the tokens to be returned to the BuddyDao contract address before returning the money owed, otherwise it cannot be actually;