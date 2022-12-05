const { expect } = require("chai");
const { show } = require("./helper/meta.js");
const BN = require('bn.js');


describe("BuddyDao", function (){

    const serviceFee = "100000000000000000";
    const maxFixedRate = "500000000000000000";
    const trustAmount = "10000000000000000000";
    const trustDoupleAmount = "20000000000000000000";
    const alias = "bob";
    const fixedRate = "50000000000000000";

    let busdAddrress,buddyDaoAddress;
    beforeEach(async () =>{
        [minter, alice, bob, carol, _] = await ethers.getSigners();
        const busdToken = await ethers.getContractFactory("BUSD");
        busdAddrress = await busdToken.deploy();
        const buddyDaoToken = await ethers.getContractFactory("BuddyDao");
        buddyDaoAddress = await buddyDaoToken.deploy(serviceFee, minter.address,maxFixedRate);
    });

    it("Lend authorizes trust operations", async function() {
        // mint busd
        await busdAddrress.connect(minter).mint(minter.address, trustAmount);
        await  buddyDaoAddress.connect(minter).NewTrust(bob.address, alias, busdAddrress.address, fixedRate, trustAmount);
        // get lend data
        const  data = await buddyDaoAddress.GetLenderIndexData(minter.address, 0);
        // console.log("data=",data);
        expect(data.Address).to.equal(bob.address);
        expect(data.CreditLine).to.equal(trustAmount);
    });

    it("Lend Remove authorization operation", async function() {
        // add auth
        await busdAddrress.connect(minter).mint(minter.address, trustAmount);
        await  buddyDaoAddress.connect(minter).NewTrust(bob.address, alias, busdAddrress.address, fixedRate, trustAmount);
        const  data = await buddyDaoAddress.GetLenderIndexData(minter.address, 0);
        expect(data.Address).to.equal(bob.address);
        expect(data.CreditLine).to.equal(trustAmount);
        // remove auth
        await buddyDaoAddress.connect(minter).RemoveTrust(bob.address,0,trustAmount)
        const  dataAfter = await buddyDaoAddress.GetLenderIndexData(minter.address, 0);
        expect(dataAfter.CreditLine).to.equal("0");
    });

    it("Borrower operation borrowing operation", async function() {
        // add auth
        await busdAddrress.connect(minter).mint(minter.address, trustAmount);
        await  buddyDaoAddress.connect(minter).NewTrust(bob.address, alias, busdAddrress.address, fixedRate, trustAmount);
        // borrower Inquiry authorization
        const  data = await buddyDaoAddress.GetBorrowerIndexData(bob.address, 0);
        expect(data.Creditors).to.equal(minter.address);
        expect(data.CreditLine).to.equal(trustAmount);
        // lend approve buddyDaoaddress
        await busdAddrress.connect(minter).approve(buddyDaoAddress.address, trustAmount);
        // get approve amounut
        expect(await busdAddrress.allowance(minter.address, buddyDaoAddress.address)).equal(trustAmount);
        // borrower actul
        await buddyDaoAddress.connect(bob).Withdrawal(minter.address, 0, trustAmount);
        // get balance
        expect(await busdAddrress.balanceOf(bob.address)).equal(trustAmount);
    });

    it("Borrower return the money owed operation", async function() {
        // add auth
        await busdAddrress.connect(minter).mint(minter.address, trustAmount);
        await  buddyDaoAddress.connect(minter).NewTrust(bob.address, alias, busdAddrress.address, fixedRate, trustAmount);
        // borrower Inquiry authorization
        const  data = await buddyDaoAddress.GetBorrowerIndexData(bob.address, 0);
        expect(data.Creditors).to.equal(minter.address);
        expect(data.CreditLine).to.equal(trustAmount);
        // lend approve
        await busdAddrress.connect(minter).approve(buddyDaoAddress.address, trustAmount);
        // get approve amount
        expect(await busdAddrress.allowance(minter.address, buddyDaoAddress.address)).equal(trustAmount);
        // borrower actual
        await buddyDaoAddress.connect(bob).Withdrawal(minter.address, 0, trustAmount);
        // get busd balance
        expect(await busdAddrress.balanceOf(bob.address)).equal(trustAmount);
        // borrower approve
        await busdAddrress.connect(bob).approve(buddyDaoAddress.address, trustDoupleAmount);
        await busdAddrress.connect(minter).mint(bob.address, trustAmount);
        await buddyDaoAddress.connect(bob).Pay(minter.address, 0, trustAmount);
    });

})