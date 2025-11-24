# **MarketInvest – Decentralized Market Insurance Contract**

MarketInvest is a smart contract that lets users buy insurance-like policies against different market risks such as market crashes, natural disasters, and stablecoin depegs. Users pay a monthly subscription and can claim payouts when the configured conditions are met.

---

## **Features**

* **Buy Policies** for:

  * Market Crash
  * Natural Disaster
  * Stablecoin Depeg
* **Monthly Subscription Model**
* **Automatic Fee Deduction** (sent to contract owner)
* **Price Feed Integration (Chainlink)**
* **Claim Payouts Automatically Based on Market Conditions**
* **Admin Controls** – Pause, Unpause, Withdraw

---

## **Policy Structure**

Each policy stores:

* Policy ID
* User Address
* Market Type
* Deposit Amount
* Last Deposit Timestamp
* Active Status
* Expiry Time

---

## **How It Works**

### **1. Buy a Policy**

* User pays **1 ETH** (monthly subscription).
* Fee = 1% (configurable via BPS).
* Net amount stored in policy.
* Policy is created with unique ID and expiry.

### **2. Invest (Renew or Top-up)**

* User pays the same subscription amount.
* Deposits added to existing policy.
* Timestamp updated.

### **3. Claim Conditions**

#### **Market Crash**

* Fetches BNB price via Chainlink.
* If price < `MIN_MARKET_CLAIM`, payout = 2× deposit.

#### **Natural Disaster**

* User provides water level input.
* If water level ≤ 20 or ≥ 100 → payout = 2× deposit.

#### **Stablecoin Depeg**

* Fetches USDT price.
* If price < 0.97 → payout = 2× deposit.

### **All claims require:**

* Policy active
* Claim within 30 days of last deposit
* Policy not expired

---

## **Admin Functions**

* **pauseContract()** – Stops buy/claim operations.
* **unpauseContract()** – Resume operations.
* **withdraw()** – Owner withdraws contract balance.

---

## **Events**

* `marketPolicyPurchased`
* `investedInPolicy`
* `claimed`
* `priceNotReachedThreshold`
* `naturalHazardIsNotAchived`

---

## **Usage Flow**

1. User buys policy (1 ETH).
2. User can renew monthly.
3. When market condition matches → user claims.
4. Contract pays user automatically.

---

## **Dependencies**

* OpenZeppelin (Ownable, Pausable)
* Chainlink Price Feeds (AggregatorV3Interface)

---

If you want, I can also format it into a **GitHub-ready README.md** with badges, code blocks, installation steps, and examples.
