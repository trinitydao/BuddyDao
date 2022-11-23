// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.



async function main() {

  const [deployer,,,,] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const serviceFee = "100000000000000000";
  const serviceFeeAddress = "0x679629069bd69eEe0E6f1c85e1DE927FbF8dab8f";
  const maxFixedRate = "500000000000000000";

  const buddyDaoToken = await ethers.getContractFactory("BuddyDao");
  const BuddyDaoToken = await buddyDaoToken.deploy(serviceFee, serviceFeeAddress, maxFixedRate);

  console.log("BuddyDaoToken address:", BuddyDaoToken.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });