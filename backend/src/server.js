import express from "express";
import cors from "cors";
import { ethers } from "ethers";
import dotenv from "dotenv";
import fs from "fs";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// -------------------------------
//  PROVIDER + WALLET + CONTRACT
// -------------------------------

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);

const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Load ABI
const abi = JSON.parse(fs.readFileSync("./abi/MarketInvest.json", "utf8"));

// Contract instance
const contract = new ethers.Contract(
  process.env.CONTRACT_ADDRESS,
  abi,
  wallet
);

// -------------------------------
//  API ROUTES
// -------------------------------

// Buy policy
app.post("/buy", async (req, res) => {
  try {
    const { expiry, type } = req.body;

    const tx = await contract.buyMarketPolicyf(
      expiry,
      type,
      { value: ethers.parseEther("1") }
    );

    await tx.wait();
    res.json({ status: "ok", tx: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

// Claim market crash
app.post("/claimCrash", async (req, res) => {
  try {
    const { policyId } = req.body;
    const tx = await contract.claimMarketCrash(policyId);
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

app.post("/claimCrash", async (req, res) => {
  try {
    const { policyId } = req.body;
    const { waterLevel } = req.body;

    const tx = await contract.claimNaturalClamity(waterLevel, policyId);
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

app.post("/claimCrash", async (req, res) => {
  try {
    const { policyId } = req.body;
    const tx = await contract.claimStableCoinPeg(policyId);
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

app.post("/claimCrash", async (req, res) => {
  try {
    const tx = await contract.withdraw();
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.toString() });
  }
});

app.post("/claimCrash", async (req, res) => {
  
    const tx = await contract.Pause();
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  
});

app.post("/claimCrash", async (req, res) => {
  
    const tx = await contract.unPause();
    await tx.wait();

    res.json({ status: "claimed", tx: tx.hash });
  
});

// -------------------------------
//  START SERVER
// -------------------------------

app.listen(5000, () => console.log("Backend running on port 5000"));
