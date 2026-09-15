# Clean Code Guide
### For Use with GitHub Copilot, AI Agents, and Code Reviews

> This document defines the standards for writing clean, readable, production-ready code across any language or codebase. Feed this to Copilot, an agent, or use it as a review checklist. Every rule here exists to make code easier to read, extend, debug, and hand off — not to look clever.

---

## Table of Contents

1. [Naming](#1-naming)
2. [Functions](#2-functions)
3. [Comments](#3-comments)
4. [Control Flow & Guard Clauses](#4-control-flow--guard-clauses)
5. [Variables & State](#5-variables--state)
6. [Magic Numbers & Hardcoded Values](#6-magic-numbers--hardcoded-values)
7. [DRY — Don't Repeat Yourself](#7-dry--dont-repeat-yourself)
8. [Boolean Discipline](#8-boolean-discipline)
9. [Abstraction Levels](#9-abstraction-levels)
10. [Classes & Objects](#10-classes--objects)
11. [SOLID Principles](#11-solid-principles)
12. [Error Handling](#12-error-handling)
13. [File Structure & Project Organization](#13-file-structure--project-organization)
14. [KISS — Keep It Simple, Stupid](#14-kiss--keep-it-simple-stupid)
15. [YAGNI — You Ain't Gonna Need It](#15-yagni--you-aint-gonna-need-it)
16. [KISS & YAGNI Interaction — The Rule of Three](#16-kiss--yagni-interaction--the-rule-of-three)
17. [Law of Demeter — Don't Talk to Strangers](#17-law-of-demeter--dont-talk-to-strangers)
18. [Command Query Separation (CQS)](#18-command-query-separation-cqs)
19. [Tell, Don't Ask](#19-tell-dont-ask)
20. [Separation of Concerns](#20-separation-of-concerns)
21. [Pure Functions](#21-pure-functions)
22. [Coupling & Cohesion](#22-coupling--cohesion)
23. [Defensive Programming](#23-defensive-programming)
24. [Code Formatting & Consistency](#24-code-formatting--consistency)
25. [Type Safety & Explicit Contracts](#25-type-safety--explicit-contracts)
26. [The Boy Scout Rule](#26-the-boy-scout-rule)
27. [Code Smells Reference](#27-code-smells-reference)
28. [Refactoring Signals](#28-refactoring-signals)
15. [Copilot / Agent Prompt Instructions](#15-copilot--agent-prompt-instructions)

---

## 1. Naming

Naming is the single most impactful thing you can do for code quality. A good name eliminates the need for a comment. A bad name forces every reader to decode intent from scratch.

### 1.1 Names Must Reveal Intent

The name should answer: *what is this, what does it hold, and why does it exist?*

```
// BAD
int d;
let x;
var flag;
string s;

// GOOD
int daysSinceLastLogin;
let currentUserScore;
var isInventoryEmpty;
string welcomeMessageTemplate;
```

If you have to look at how a variable is used to understand what it is, the name is wrong.

### 1.2 No Abbreviations

Write out the full word. The characters you save cost the next reader seconds of decoding time, every single read.

```
// BAD
deltaTime → dt
direction → dir
index     → idx
player    → plr
velocity  → vel
previous  → prev

// GOOD
deltaTime     stays deltaTime
direction     stays direction
index         stays index
playerCharacter is fine
velocity      stays velocity
previousValue stays previousValue
```

**Exceptions:** Universally accepted short forms are fine — `min`, `max`, `id`, `url`, `http`, `api`, `ui`. If a junior dev with no context would instantly know it, it's allowed.

### 1.3 Name Booleans as Yes/No Questions

A boolean should read like something you'd answer with "yes" or "no." If you can't form a question from it, rename it.

```
// BAD
bool loaded;
bool active;
bool dead;
bool check;

// GOOD
bool isLoaded;
bool isActive;
bool isDead;
bool hasPassedValidation;
bool canPlayerJump;
bool wasAnimationTriggered;
```

### 1.4 Name Functions as Actions

Functions do things. Their names should start with a strong verb that describes exactly what they do.

```
// BAD
function data() {}
function user() {}
function thing() {}
function process() {}   // too vague
function handle() {}    // too vague
function manage() {}    // too vague

// GOOD
function fetchUserData() {}
function validateEmailFormat() {}
function applyDamageToTarget() {}
function calculateTotalCartPrice() {}
function resetPlayerMovementState() {}
```

### 1.5 Name Classes as Nouns

Classes are things, not actions.

```
// BAD
class ProcessData {}
class HandleInput {}

// GOOD
class DataProcessor {}
class InputHandler {}
class UserRepository {}
class ShoppingCart {}
```

### 1.6 No Filler Words

Words like `data`, `info`, `manager`, `helper`, `utils`, `stuff`, and `handler` are usually filler. They describe nothing. Replace them with what the thing actually is.

```
// BAD
UserManager     → what does it manage? UserRepository? UserAuthenticator?
DataHelper      → DataFormatter? DataValidator?
InfoProcessor   → what info? InvoiceParser? LogAggregator?

// GOOD
UserRepository         (stores/retrieves users)
EmailValidator         (validates email format)
InvoiceParser          (parses invoice data)
AnimationController    (controls animation state)
```

### 1.7 Name Collections as Plurals

```
// BAD
let playerList;
let itemArray;
let userData;

// GOOD
let players;
let items;
let users;
```

### 1.8 Avoid Misleading Names

A name that lies is worse than no name at all. Never name something in a way that implies behavior it doesn't have.

```
// BAD — name implies a list, but it's just one player
let playerList = currentPlayer;

// BAD — name implies it does nothing, but it deletes records
function doStuff() { db.deleteAll(); }

// BAD — name implies a boolean but it returns a string
let isUserName = getUserName();
```

### 1.9 Consistent Vocabulary

Pick one word per concept and use it everywhere. Don't mix `fetch`, `get`, `retrieve`, and `load` for the same operation across different parts of the codebase.

```
// BAD — same concept, four different words
fetchUser()
getOrder()
retrieveProduct()
loadInvoice()

// GOOD — pick one
fetchUser()
fetchOrder()
fetchProduct()
fetchInvoice()
```

---

## 2. Functions

Functions are the primary unit of logic. They should be small, focused, and have exactly one job.

### 2.1 Do One Thing

If you can describe a function's job using the word "and," it does too much. Split it.

```
// BAD — does three separate things
function processAndSaveUser(userData) {
    validateEmail(userData.email);
    userData.createdAt = Date.now();
    db.save(userData);
    emailService.sendWelcome(userData.email);
}

// GOOD — each function does one thing
function createUser(userData) {
    const validatedUser = validateAndPrepareUser(userData);
    saveUserToDatabase(validatedUser);
    sendWelcomeEmail(validatedUser.email);
}

function validateAndPrepareUser(userData) {
    validateEmail(userData.email);
    return { ...userData, createdAt: Date.now() };
}
```

### 2.2 Small Functions

Functions should be short enough to read in one glance. There's no hard line count rule, but if a function requires scrolling, it almost certainly does too much. Aim for 5–15 lines for pure logic functions. Complex orchestration functions can be longer, but must remain readable top-to-bottom without mental state tracking.

### 2.3 One Level of Abstraction Per Function

All statements in a function should be at the same level of detail. Don't mix high-level decisions with low-level implementation in the same function.

```
// BAD — mixes high-level flow with low-level detail
function processCheckout(cart) {
    let total = 0;
    for (let item of cart.items) {      // low level detail
        total += item.price * item.quantity;
    }
    if (total > 1000) {
        total *= 0.9;
    }
    db.execute(`INSERT INTO orders VALUES (${total})`);  // very low level
    emailService.send(cart.user.email, "Order confirmed");
}

// GOOD — one level of abstraction throughout
function processCheckout(cart) {
    const orderTotal = calculateDiscountedTotal(cart.items);
    saveOrderToDatabase(cart.user, orderTotal);
    sendOrderConfirmationEmail(cart.user.email);
}
```

### 2.4 Minimize Arguments

Every argument is a concept the reader has to hold in their head. Aim for 0–2 arguments. Three is a warning sign. Four or more almost always means something is wrong.

```
// BAD — 6 arguments, impossible to read at call site
createUser("Ethan", "ethan@email.com", true, false, "admin", Date.now());

// GOOD — pass an object
createUser({
    name: "Ethan",
    email: "ethan@email.com",
    isVerified: true,
    isSubscribed: false,
    role: "admin",
    createdAt: Date.now()
});
```

### 2.5 No Side Effects

A function should do what its name says and nothing else. Hidden side effects are one of the most common sources of bugs.

```
// BAD — name says "validate," but it also mutates userData and logs
function validateUser(userData) {
    userData.validatedAt = Date.now();   // side effect
    console.log("Validating:", userData);  // side effect
    return userData.email.includes("@");
}

// GOOD
function isValidUser(userData) {
    return userData.email.includes("@");
}
```

### 2.6 Functions That Return Are Better Than Functions That Mutate

Prefer returning new values over mutating inputs. This makes functions testable, predictable, and composable.

```
// BAD — mutates the input
function applyDiscount(order) {
    order.total = order.total * 0.9;
}

// GOOD — returns a new value
function applyDiscount(order) {
    return { ...order, total: order.total * 0.9 };
}
```

---

## 3. Comments

Comments are not inherently good. A comment that explains *what* the code does is a failure of the code to explain itself. Write code that doesn't need comments.

### 3.1 Comments Explain WHY, Not WHAT

The only valid reason to write a comment is to explain something the code cannot express: why a specific decision was made, why an expected approach was avoided, or why a non-obvious workaround is necessary.

```
// BAD — describes what the code already shows
// Loop through users
for (let user of users) { ... }

// BAD — restates the variable name
let timeout = 5000; // set timeout to 5000ms

// GOOD — explains a non-obvious reason
// Delay is intentional — the external API rate-limits to 1 req/sec
await sleep(1000);

// GOOD — explains why a seemingly wrong approach is correct
// Subtract 1 because the API returns 1-indexed pages but our cache is 0-indexed
const cacheKey = apiPage - 1;
```

### 3.2 Never Comment Out Dead Code

Commented-out code is noise. It causes confusion about whether the code is intentional, deprecated, or forgotten. Delete it. Version control exists for this exact reason.

```
// BAD
// function oldFetch(id) {
//     return db.query(`SELECT * FROM users WHERE id = ${id}`);
// }

// GOOD — just delete it. It's in git history if you need it.
```

### 3.3 TODO Comments Must Include Context

A `TODO` with no context is useless. If you write one, include who, why, and ideally a ticket reference.

```
// BAD
// TODO: fix this

// GOOD
// TODO: Replace with paginated fetch once API v2 is live — Ethan, #482
```

### 3.4 Never Write Redundant Comments

If the code is clear, the comment adds nothing but clutter.

```
// BAD
// Returns the user's name
function getUserName() {
    return this.name;
}

// GOOD — no comment needed, the code is self-explanatory
function getUserName() {
    return this.name;
}
```

---

## 4. Control Flow & Guard Clauses

Deep nesting is one of the clearest signals that code needs refactoring. Every level of indentation adds cognitive load. Flatten it.

### 4.1 Use Guard Clauses (Early Returns)

Validate and exit early instead of wrapping the happy path in nested conditions.

```
// BAD — happy path is deeply nested
function processPayment(user, cart) {
    if (user) {
        if (cart.items.length > 0) {
            if (user.hasSufficientFunds(cart.total)) {
                chargeUser(user, cart.total);
                sendReceipt(user.email);
            } else {
                throw new Error("Insufficient funds");
            }
        } else {
            throw new Error("Cart is empty");
        }
    } else {
        throw new Error("User not found");
    }
}

// GOOD — guard clauses exit early, happy path is clear and unindented
function processPayment(user, cart) {
    if (!user) throw new Error("User not found");
    if (cart.items.length === 0) throw new Error("Cart is empty");
    if (!user.hasSufficientFunds(cart.total)) throw new Error("Insufficient funds");

    chargeUser(user, cart.total);
    sendReceipt(user.email);
}
```

### 4.2 Invert Conditions to Reduce Nesting

When an `if` block is large and the `else` is small, invert the condition and return/throw early.

```
// BAD
if (isAuthorized) {
    // 40 lines of logic
    ...
} else {
    throw new Error("Unauthorized");
}

// GOOD
if (!isAuthorized) throw new Error("Unauthorized");

// 40 lines of logic, cleanly
...
```

### 4.3 Avoid Else After Return

If an `if` block returns or throws, there is no need for an `else`. The `else` is implicit.

```
// BAD
function getDiscount(memberType) {
    if (memberType === "premium") {
        return 0.2;
    } else if (memberType === "standard") {
        return 0.1;
    } else {
        return 0;
    }
}

// GOOD
function getDiscount(memberType) {
    if (memberType === "premium") return 0.2;
    if (memberType === "standard") return 0.1;
    return 0;
}
```

### 4.4 Limit Nesting to 2 Levels Max

If you're three or more levels deep, extract inner logic into a named function.

```
// BAD — 4 levels deep
for (let user of users) {
    if (user.isActive) {
        for (let order of user.orders) {
            if (order.isPending) {
                processOrder(order);
            }
        }
    }
}

// GOOD — extracted, each piece is readable independently
function processPendingOrdersForActiveUsers(users) {
    const activeUsers = users.filter(user => user.isActive);
    activeUsers.forEach(user => processPendingOrders(user.orders));
}

function processPendingOrders(orders) {
    orders.filter(order => order.isPending).forEach(processOrder);
}
```

### 4.5 Replace Complex Conditionals with Named Variables

If a condition is long or non-obvious, extract it into a named boolean variable that explains what you're checking.

```
// BAD — what does this mean?
if (user.age >= 18 && user.country !== "US" && !user.isBanned && user.subscriptionLevel > 1) {
    showPremiumContent();
}

// GOOD — the condition is self-documenting
const isEligibleForPremium =
    user.age >= 18 &&
    user.country !== "US" &&
    !user.isBanned &&
    user.subscriptionLevel > 1;

if (isEligibleForPremium) {
    showPremiumContent();
}
```

---

## 5. Variables & State

### 5.1 Declare Variables Close to Use

Variables should be declared as close to where they're used as possible. Declaring them all at the top of a function forces readers to scroll back and forth.

```
// BAD
function calculateInvoice(items) {
    let subtotal;
    let discount;
    let tax;
    let total;

    subtotal = items.reduce((sum, item) => sum + item.price, 0);
    // ... 30 lines later
    discount = subtotal > 100 ? 0.1 : 0;
    // ... 20 more lines
    tax = (subtotal - discount) * 0.08;
    total = subtotal - discount + tax;
}

// GOOD
function calculateInvoice(items) {
    const subtotal = items.reduce((sum, item) => sum + item.price, 0);
    const discount = subtotal > 100 ? 0.1 : 0;
    const tax = (subtotal - discount) * 0.08;
    const total = subtotal - discount + tax;
    return total;
}
```

### 5.2 Prefer Immutability

Use `const` by default. Use `let` only when you genuinely need to reassign. Never use `var`. Immutable values are easier to reason about because you know they can't change behind your back.

### 5.3 Avoid Temporary Variables That Just Return

If a variable is created only to be immediately returned, skip it.

```
// BAD
function getFullName(user) {
    const fullName = `${user.firstName} ${user.lastName}`;
    return fullName;
}

// GOOD
function getFullName(user) {
    return `${user.firstName} ${user.lastName}`;
}
```

**Exception:** If the variable name meaningfully adds clarity beyond what the expression provides, keep it.

### 5.4 Minimize Mutable State

Every mutable variable is a liability. Track mutations carefully. If state can be computed from other state, derive it instead of storing it.

```
// BAD — isCartEmpty is redundant derived state
let cartItems = [];
let isCartEmpty = true;

cartItems.push(item);
isCartEmpty = cartItems.length === 0;  // easy to forget to update

// GOOD — derive it
let cartItems = [];
const isCartEmpty = () => cartItems.length === 0;
```

---

## 6. Magic Numbers & Hardcoded Values

A number or string literal sitting inline in code is called a "magic number" — it has an implicit meaning that only the original author knows. Always extract them into named constants.

### 6.1 Extract All Meaningful Literals

```
// BAD
if (player.health < 20) { flashHealthWarning(); }
const timeout = setTimeout(callback, 5000);
if (userRole === 3) { grantAdminAccess(); }

// GOOD
const CriticalHealthThreshold = 20;
const SessionTimeoutMs = 5000;
const RoleAdmin = 3;

if (player.health < CriticalHealthThreshold) { flashHealthWarning(); }
const timeout = setTimeout(callback, SessionTimeoutMs);
if (userRole === RoleAdmin) { grantAdminAccess(); }
```

### 6.2 Group Constants Logically

Put related constants together — in a config object, a constants file, or an enum — so they're easy to find and update.

```
// GOOD — grouped config object
const PhysicsConfig = {
    gravity: 9.81,
    jumpForce: 15.0,
    maxFallSpeed: 50.0,
    frictionCoefficient: 0.8
};

const HttpStatus = {
    ok: 200,
    created: 201,
    badRequest: 400,
    unauthorized: 401,
    notFound: 404,
    serverError: 500
};
```

### 6.3 No Hardcoded Strings for Logic

Strings used for comparison or branching should be constants, not inline literals. Typos in inline strings are invisible until runtime.

```
// BAD
if (user.role === "adminstrator") { ... }  // typo, silent bug

// GOOD
const Roles = { admin: "administrator", editor: "editor", viewer: "viewer" };
if (user.role === Roles.admin) { ... }
```

---

## 7. DRY — Don't Repeat Yourself

Every piece of knowledge should have a single, authoritative representation in the codebase. Duplication means two places to update, two places to forget, two places to introduce bugs.

### 7.1 Spot and Extract Repeated Logic

If you see the same block of logic in two places, it belongs in a function.

```
// BAD — validation logic duplicated in two routes
app.post("/register", (req, res) => {
    if (!req.body.email.includes("@")) return res.status(400).send("Invalid email");
    if (req.body.password.length < 8) return res.status(400).send("Password too short");
    // ...
});

app.post("/update-profile", (req, res) => {
    if (!req.body.email.includes("@")) return res.status(400).send("Invalid email");
    if (req.body.password.length < 8) return res.status(400).send("Password too short");
    // ...
});

// GOOD
function validateUserCredentials(email, password) {
    if (!email.includes("@")) throw new Error("Invalid email");
    if (password.length < 8) throw new Error("Password too short");
}

app.post("/register", (req, res) => {
    validateUserCredentials(req.body.email, req.body.password);
    // ...
});
```

### 7.2 DRY Applies to Configuration Too

Don't paste the same base URL, timeout value, or config block in multiple places. Define it once.

### 7.3 Don't Over-DRY (Wrong Abstraction)

DRY applies to *identical logic*, not *similar-looking code*. Two blocks that look alike but serve different concepts for different reasons should *not* be merged. Merging them creates a wrong abstraction that's worse than duplication. If unifying two things requires adding a parameter to distinguish between them on every call, it's probably the wrong abstraction.

```
// RISKY — looks like DRY but these two things may diverge
function renderCard(type) {
    if (type === "product") { ... }
    else if (type === "user") { ... }
}

// BETTER if they serve different concerns
function renderProductCard() { ... }
function renderUserCard() { ... }
```

---

## 8. Boolean Discipline

### 8.1 Never Use Boolean Parameters for Branching

A boolean parameter that changes what a function does is a design smell. The function is actually two different functions wearing a mask.

```
// BAD — what does `true` mean at the call site?
sendEmail(user, true);
renderButton(label, false);

// GOOD — separate functions with clear intent
sendWelcomeEmail(user);
sendNotificationEmail(user);

renderPrimaryButton(label);
renderSecondaryButton(label);
```

### 8.2 Avoid Negative Boolean Names

Negative variable names require double-negation to reason about. Always phrase booleans positively.

```
// BAD — requires double-negation to parse
if (!isNotLoggedIn) { ... }
bool isNotEnabled;
bool isInvalid;

// GOOD
if (isLoggedIn) { ... }
bool isEnabled;
bool isValid;
```

### 8.3 Don't Compare Booleans to True/False

```
// BAD
if (isLoaded === true) { ... }
if (hasError === false) { ... }

// GOOD
if (isLoaded) { ... }
if (!hasError) { ... }
```

---

## 9. Abstraction Levels

### 9.1 Name the "What," Implement the "How"

High-level code should describe *what* is happening. Low-level code should describe *how*. These should live at different layers.

```
// BAD — a high-level function that contains low-level detail
function startGame() {
    document.getElementById("canvas").style.display = "block";
    window.requestAnimationFrame(gameLoop);
    localStorage.setItem("session_start", Date.now());
}

// GOOD — high-level describes what, delegates how
function startGame() {
    showGameCanvas();
    beginGameLoop();
    recordSessionStart();
}
```

### 9.2 Don't Leak Implementation Details

The caller should not need to know how something works internally. Encapsulate the details.

```
// BAD — caller has to understand the internal structure
const userName = userRecord.data.profile.personalInfo.displayName;

// GOOD — encapsulate behind a method
const userName = user.getDisplayName();
```

### 9.3 Avoid Premature Abstraction

Only abstract when you have two or more concrete examples that justify it. Abstracting too early creates complexity for a hypothetical future that may never arrive. Write it concretely first, then extract once the pattern is clear.

---

## 10. Classes & Objects

### 10.1 Classes Should Have One Responsibility

A class should represent one concept. If it has methods that serve completely different concerns, split it.

```
// BAD — this class handles parsing, validation, and persistence
class User {
    parseFromJSON(json) { ... }
    validateEmail() { ... }
    saveToDatabase() { ... }
    sendWelcomeEmail() { ... }
}

// GOOD — each class has one concern
class User { ... }                    // represents the entity
class UserValidator { ... }           // validates user data
class UserRepository { ... }          // persistence
class UserEmailService { ... }        // email operations
```

### 10.2 Small Interfaces, Clear Contracts

Expose only what callers need. Everything else is private. The public interface is a contract — keep it minimal and stable.

### 10.3 Prefer Composition Over Inheritance

Inheritance creates tight coupling and makes code fragile when requirements change. Composition (injecting or composing smaller objects) is almost always more flexible.

```
// RISKY — deep inheritance chains
class Animal {}
class LivingCreature extends Animal {}
class Mammal extends LivingCreature {}
class Pet extends Mammal {}
class Dog extends Pet {}

// BETTER — compose behaviors
class Dog {
    constructor() {
        this.locomotion = new WalkingBehavior();
        this.sound = new BarkingBehavior();
        this.feeding = new CarnivoreFeeding();
    }
}
```

### 10.4 Constructor Does Setup, Not Work

Constructors should initialize state. Heavy computation, async operations, and side effects belong in a dedicated `init()` or `setup()` method.

---

## 11. SOLID Principles

These five principles apply universally to object-oriented and modular code.

### 11.1 S — Single Responsibility Principle

A module, class, or function should have one reason to change. If you can list two different stakeholders who might ask you to change the same file for completely different reasons, it has too many responsibilities.

### 11.2 O — Open/Closed Principle

Code should be open to extension but closed to modification. New behavior should be addable without editing existing, working code.

```
// BAD — adding a new shape requires modifying this function
function getArea(shape) {
    if (shape.type === "circle") return Math.PI * shape.radius ** 2;
    if (shape.type === "square") return shape.side ** 2;
    // every new shape = modify this function
}

// GOOD — each shape knows its own area
class Circle {
    getArea() { return Math.PI * this.radius ** 2; }
}
class Square {
    getArea() { return this.side ** 2; }
}
// Adding a Triangle: just add a Triangle class. No existing code changes.
```

### 11.3 L — Liskov Substitution Principle

Subclasses must be usable anywhere their parent class is expected, without breaking behavior. If a subclass removes or overrides behavior in a way that changes the contract, the inheritance hierarchy is wrong.

### 11.4 I — Interface Segregation Principle

No code should be forced to depend on methods it doesn't use. Prefer many small, specific interfaces over one large, general one.

```
// BAD — not every user of this interface needs all three methods
interface DataManager {
    read();
    write();
    delete();
}

// GOOD — separate concerns
interface DataReader { read(); }
interface DataWriter { write(); }
interface DataDeleter { delete(); }
```

### 11.5 D — Dependency Inversion Principle

High-level modules should not depend on low-level modules. Both should depend on abstractions. Inject dependencies rather than hard-wiring them.

```
// BAD — tightly coupled to a specific database implementation
class UserService {
    constructor() {
        this.db = new PostgresDatabase();  // hard dependency
    }
}

// GOOD — depends on an abstraction, not a concrete implementation
class UserService {
    constructor(database) {
        this.db = database;  // injected — can be Postgres, SQLite, a mock, anything
    }
}
```

---

## 12. Error Handling

### 12.1 Never Silently Swallow Errors

An empty catch block is one of the most dangerous patterns in software. If you catch an error, do something with it.

```
// BAD — error disappears silently
try {
    parseConfig(file);
} catch (error) {}

// GOOD
try {
    parseConfig(file);
} catch (error) {
    logger.error("Failed to parse config file:", error);
    throw new ConfigurationError("Could not load configuration", { cause: error });
}
```

### 12.2 Throw Meaningful Errors

Errors should describe exactly what went wrong and what context led to it. Generic errors like `"Something went wrong"` are useless.

```
// BAD
throw new Error("Error");
throw new Error("Failed");

// GOOD
throw new Error(`User with ID ${userId} not found in database`);
throw new Error(`Payment rejected: amount ${amount} exceeds limit of ${MAX_PAYMENT}`);
```

### 12.3 Validate at the Boundary

Validate inputs at the point they enter your system (API handlers, function entry points, constructors). Don't spread defensive checks throughout internal logic.

### 12.4 Use Typed/Custom Errors When Appropriate

Custom error types let callers distinguish between different failure modes without parsing strings.

```
class ValidationError extends Error {}
class NetworkError extends Error {}
class NotFoundError extends Error {}

try {
    await fetchUser(id);
} catch (error) {
    if (error instanceof NotFoundError) redirectTo404();
    else if (error instanceof NetworkError) showRetryPrompt();
    else throw error;  // unexpected — let it propagate
}
```

### 12.5 Don't Use Exceptions for Control Flow

Exceptions are for exceptional, unexpected conditions — not for normal branching logic.

```
// BAD — using exceptions for control flow
try {
    const user = findUser(id);
} catch (NotFoundError) {
    return createNewUser();  // this is normal logic, not an exception
}

// GOOD
const user = findUser(id) ?? createNewUser();
```

---

## 13. File Structure & Project Organization

A well-organized project is readable before a single line of code is opened. Folder names, file names, and the way things are split should tell the story of what the project does and where everything lives.

### 13.1 One File, One Purpose

Every file should have a single, clear job. Its name should make that job immediately obvious to someone who has never seen the codebase before.

```
// BAD — vague dumping grounds
utils.js
helpers.ts
misc.lua
common.cs
stuff.py
shared.js

// GOOD — PascalCase, each file has an unambiguous, specific purpose
DateFormatter.js
EmailValidator.ts
PhysicsCalculator.lua
UserRepository.cs
StringNormalizer.py
AnimationHelpers.js     // only if the contents truly are animation-related helpers
```

If you can't name a file without using a vague word, the file contains too many unrelated things. Split it.

### 13.2 Folder Names Describe What They Contain

Folders are the top-level map of your project. Their names should be lowercase, plural where appropriate, and describe the category of content inside — not the technical layer.

```
// BAD — technical layer names, not descriptive
/controllers
/models
/views
/misc
/new
/old
/temp

// GOOD — PascalCase, descriptive, intention-revealing names
/Features          → feature modules grouped by what they do
/Services          → business logic, external integrations
/Components        → reusable UI pieces
/Utils             → only truly generic, stateless utility functions
/Config            → all configuration and constants
/Types             → type definitions and interfaces (TS/C#/etc.)
/Assets            → static files (images, fonts, sounds)
/Tests             → all test files, mirroring the source structure
```

### 13.3 Feature-Based vs. Layer-Based Structure

**Layer-based** (bad at scale): groups all models together, all controllers together. A change to one feature touches multiple folders.

**Feature-based** (good at scale): groups everything for one feature together. A change to one feature stays in one folder.

```
// LAYER-BASED — hard to navigate as the project grows
Src/
  Models/
    User.js
    Order.js
    Product.js
  Controllers/
    UserController.js
    OrderController.js
    ProductController.js
  Services/
    UserService.js
    OrderService.js
    ProductService.js

// FEATURE-BASED — each feature is self-contained
Src/
  Features/
    User/
      UserModel.js
      UserController.js
      UserService.js
      UserValidator.js
    Order/
      OrderModel.js
      OrderController.js
      OrderService.js
    Product/
      ProductModel.js
      ProductController.js
      ProductService.js
  Shared/
    Database.js
    Logger.js
    ErrorHandler.js
```

Use layer-based only for very small projects. Switch to feature-based the moment you have more than 3–4 features.

### 13.4 Shared vs. Feature-Specific Code

Anything used by exactly one feature lives inside that feature's folder. Anything used by two or more features moves to a `shared/` or `common/` folder.

```
Src/
  Features/
    Checkout/
      CheckoutController.js    ← only checkout uses this
      CheckoutService.js       ← only checkout uses this
      PriceCalculator.js       ← only checkout uses this
  Shared/
    FormatCurrency.js          ← used by Checkout AND Invoice AND Dashboard
    Logger.js                  ← used everywhere
    HttpClient.js              ← used by multiple services
```

Never reach across feature folders. `checkout/` should never import directly from `order/`. If they share something, it belongs in `shared/`.

### 13.5 Configuration & Constants Live in One Place

All magic values, environment config, feature flags, and tuning parameters belong in a dedicated `config/` folder. Nothing else in the codebase should define these values.

```
config/
  appConfig.js         → environment variables, base URLs, timeouts
  featureFlags.js      → on/off switches for features
  gameConfig.js        → (game projects) tuning values: speed, damage, rates
  theme.js             → design tokens: colors, spacing, font sizes
  routes.js            → all route strings defined once
```

Inside these files, group related constants into named objects rather than exporting a flat list of variables.

```javascript
// BAD — flat list, hard to scan
export const MaxHealth = 100;
export const MinHealth = 0;
export const BaseSpeed = 16;
export const SprintSpeed = 24;
export const JumpForce = 50;
export const Gravity = 196;

// GOOD — grouped by concept
export const HealthConfig = {
    max: 100,
    min: 0,
    criticalThreshold: 20
};

export const MovementConfig = {
    baseSpeed: 16,
    sprintSpeed: 24,
    jumpForce: 50,
    gravity: 196
};
```

### 13.6 Test Files Mirror the Source Structure

Tests should live in a `/tests` folder that mirrors the source tree exactly, with the same folder hierarchy and file names — just with a `.test` or `.spec` suffix.

```
Src/
  Features/
    User/
      UserService.js
      UserValidator.js
Tests/
  Features/
    User/
      UserService.test.js
      UserValidator.test.js
```

Never scatter test files next to source files unless the framework explicitly requires it (e.g., some Go conventions). Keeping them separate makes it trivial to exclude tests from builds and easy to find the test for any given file.

### 13.7 Index Files as Clean Entry Points

When a folder contains multiple related files, use an `index` file to export a clean public interface. Callers import from the folder, not from specific internal files.

```javascript
// WITHOUT index — callers know too much about internals
import { UserService } from "./Features/User/UserService";
import { UserValidator } from "./Features/User/UserValidator";
import { UserRepository } from "./Features/User/UserRepository";

// WITH index — clean public interface
// Features/User/Index.js
export { UserService } from "./UserService";
export { UserValidator } from "./UserValidator";
export { UserRepository } from "./UserRepository";

// Callers now import cleanly
import { UserService, UserValidator } from "./Features/User";
```

Only export what is genuinely public. Internal helpers used only within the feature folder should not appear in the index.

### 13.8 Naming Conventions

#### Files & Folders — Always PascalCase

All files and folders use PascalCase, no exceptions. This makes the structure consistent and scannable regardless of language or context.

```
// BAD
features/
  user/
    userService.js
    userValidator.js
  order/
    orderController.js

// GOOD
Features/
  User/
    UserService.js
    UserValidator.js
  Order/
    OrderController.js
```

#### Code — camelCase by Default, with Language Exceptions

Inside the code itself, use camelCase for variables, functions, and module-level identifiers. Languages with established PascalCase conventions for specific constructs follow their own standard.

| Construct | Convention | Example |
|---|---|---|
| Variables | `camelCase` | `currentUserScore`, `isInventoryEmpty` |
| Functions / methods (JS, Lua, Python, etc.) | `camelCase` | `fetchUserData()`, `applyDamage()` |
| Constants (module-level) | `PascalCase` | `MaxHealth`, `SessionTimeoutMs` |
| Classes (all languages) | `PascalCase` | `UserRepository`, `AnimationController` |
| C# variables & parameters | `camelCase` | `currentUser`, `orderId` |
| C# methods & functions | `PascalCase` | `GetUserById()`, `SendEmail()` |
| C# properties | `PascalCase` | `UserName`, `IsActive` |
| C++ classes & structs | `PascalCase` | `PhysicsBody`, `RenderTarget` |
| C++ methods | `PascalCase` | `GetVelocity()`, `ApplyForce()` |
| Interfaces (TS / C#) | `PascalCase`, prefix `I` in C# | `Serializable`, `IUserRepository` |
| Enums | `PascalCase` (type and values) | `enum UserRole { Admin, Editor }` |
| Files | `PascalCase` | `UserService.js`, `OrderController.cs` |
| Folders | `PascalCase` | `Features/`, `SharedUtils/` |

The rule is simple: **everything in the file explorer is PascalCase. Inside the code, use camelCase by default — unless your language (C#, C++) requires PascalCase for methods and properties, in which case follow the language.**

### 13.9 Canonical Project Structure Reference

This is a general-purpose structure that works for most projects. Adapt it to your stack, but keep the principles intact.

```
ProjectRoot/
│
├── Src/                          → all source code lives here
│   ├── Features/                 → one folder per feature/domain
│   │   ├── Auth/
│   │   │   ├── AuthController.js
│   │   │   ├── AuthService.js
│   │   │   ├── AuthValidator.js
│   │   │   └── Index.js
│   │   ├── User/
│   │   │   ├── UserController.js
│   │   │   ├── UserService.js
│   │   │   ├── UserRepository.js
│   │   │   └── Index.js
│   │   └── Order/
│   │       ├── OrderController.js
│   │       ├── OrderService.js
│   │       └── Index.js
│   │
│   ├── Shared/                   → used by 2+ features
│   │   ├── Logger.js
│   │   ├── HttpClient.js
│   │   ├── ErrorHandler.js
│   │   └── Formatters/
│   │       ├── DateFormatter.js
│   │       └── CurrencyFormatter.js
│   │
│   ├── Config/                   → all constants and configuration
│   │   ├── AppConfig.js
│   │   ├── FeatureFlags.js
│   │   └── Routes.js
│   │
│   ├── Types/                    → type definitions / interfaces
│   │   ├── User.types.ts
│   │   └── Order.types.ts
│   │
│   └── Main.js                   → entry point only — no logic here
│
├── Tests/                        → mirrors Src/ structure
│   ├── Features/
│   │   ├── Auth/
│   │   │   └── AuthService.test.js
│   │   └── User/
│   │       └── UserService.test.js
│   └── Shared/
│       └── Logger.test.js
│
├── Assets/                       → static files
│   ├── Images/
│   ├── Fonts/
│   └── Sounds/
│
├── Docs/                         → documentation
│   └── CleanCodeGuide.md
│
├── .env.example                  → environment variable template (never commit .env)
├── .gitignore
├── README.md                     → project overview and setup instructions
└── package.json / .csproj / etc.
```

### 13.10 The Entry Point Does Nothing

The main entry file (`main.js`, `index.js`, `Program.cs`, `init.lua`, etc.) should contain zero business logic. Its only job is to wire things together and start the application.

```javascript
// BAD — main.js with logic
const users = db.query("SELECT * FROM users");
users.forEach(user => {
    if (user.isActive) sendEmail(user);
});

// GOOD — main.js as pure wiring
import { createApp } from "./app";
import { connectDatabase } from "./shared/database";
import { appConfig } from "./config/appConfig";

async function main() {
    await connectDatabase(appConfig.databaseUrl);
    createApp().listen(appConfig.port);
}

main();
```

---

## 14. KISS — Keep It Simple, Stupid

Complexity is the enemy of reliability. If there are two solutions and one is simpler, the simpler one is almost always better — even if the complex one feels more clever or impressive. Simple code is easier to read, test, debug, extend, and hand off.

### 14.1 Simple Is Not the Same as Easy

Simple means fewer moving parts, fewer dependencies, fewer concepts the reader has to hold in their head. Easy means familiar. These are different things. Choosing a complex pattern you're comfortable with over a simple one you have to think about is the wrong trade.

### 14.2 Don't Be Clever

Clever code is a trap. It might feel satisfying to write but it costs every future reader — including yourself six months later — cognitive overhead to decode.

```
// BAD — clever but opaque
const result = data?.items?.reduce((acc, cur) => ({...acc, [cur.id]: cur}), {}) ?? {};

// GOOD — clear intent, readable by anyone
const result = {};
if (data && data.items) {
    for (const item of data.items) {
        result[item.id] = item;
    }
}
```

If you have to explain what a line does to a teammate, rewrite it.

### 14.3 Solve the Actual Problem

Don't build a framework when you need a function. Don't build a plugin system when you have two cases. Don't add layers of abstraction for a problem you don't have yet.

```
// BAD — over-engineered for the actual problem
class DataTransformerFactory {
    static create(type) {
        return DataTransformerRegistry.get(type).buildInstance();
    }
}

// GOOD — if there are only two cases
function transformData(data, type) {
    if (type === "csv") return toCsv(data);
    if (type === "json") return toJson(data);
    throw new Error(`Unsupported format: ${type}`);
}
```

### 14.4 Complexity Budget

Every codebase has an implicit complexity budget. Spend it on the hard parts of your problem — the actual business logic, the performance-critical paths, the genuinely tricky edge cases. Don't waste it on infrastructure, ceremony, or showing off.

---

## 15. YAGNI — You Ain't Gonna Need It

Don't write code for requirements that don't exist yet. Build exactly what is needed right now, and nothing more. Every line of speculative code is debt — it has to be maintained, tested, documented, and understood, even if it never gets used.

### 15.1 Build for Now, Design for Change

YAGNI is not an excuse to write rigid code. Write clean, modular code that is easy to extend when the time comes — but don't pre-extend it for extensions you're guessing at.

```
// BAD — built for hypothetical future payment methods nobody asked for
class PaymentProcessor {
    constructor(strategy) { this.strategy = strategy; }
    process(amount) { return this.strategy.execute(amount); }
}
class StripeStrategy { execute(amount) { ... } }
class PaypalStrategy { execute(amount) { ... } }
class CryptoStrategy { execute(amount) { ... } }   // no one asked for this

// GOOD — ship Stripe, add abstraction when a second provider is actually needed
function processStripePayment(amount) { ... }
```

### 15.2 Every Unused Feature Has a Cost

Parameters that do nothing, flags that are never set, configuration options that nobody uses, generics where concrete types would do — all of these add cognitive overhead to every reader, forever. Delete them.

### 15.3 When to Add Abstraction

Add abstraction when you have two or more real, concrete cases that justify it. Not one. Not zero. Two concrete examples tell you the shape of the right abstraction. One concrete case and a guess about the future tells you nothing useful.

---

## 16. KISS & YAGNI Interaction — The Rule of Three

When you write a piece of logic once, write it directly. When you write it a second time, note the duplication but keep going. When you write it a third time, extract it into a shared abstraction. This is the Rule of Three — it's the practical reconciliation of KISS (don't over-abstract prematurely) and DRY (don't repeat yourself endlessly).

---

## 17. Law of Demeter — Don't Talk to Strangers

A function or method should only communicate with its immediate collaborators. It should not reach through one object to access the internals of another.

A method is allowed to call methods on:
- Itself
- Objects it owns (its fields)
- Objects passed as arguments
- Objects it created itself

It should never chain through unrelated objects to reach something deeper.

### 17.1 Chain Length Is a Warning Sign

```
// BAD — method reaches through three objects to get what it needs
const city = user.getAddress().getLocation().getCity();

// BAD — this couples you to the entire chain's internal structure
order.getCustomer().getProfile().getEmail().send(message);

// GOOD — ask the nearest object for what you need
const city = user.getCity();                    // User handles the internal navigation
order.notifyCustomer(message);                  // Order handles how to reach the customer
```

### 17.2 Why It Matters

Long chains create hidden dependencies. If `Address` changes how it stores location, or `Location` changes how it exposes city, every caller that chains through to `.getCity()` breaks. Encapsulate the navigation inside the object that owns the data.

### 17.3 Fluent Interfaces Are an Exception

Method chaining on the same object (fluent builder patterns, query builders) is fine. The Law of Demeter applies to reaching through different objects, not to chaining methods on one.

```
// FINE — same object, fluent interface
query.select("users").where("isActive", true).limit(20).execute();

// VIOLATION — different objects at each step
app.getRouter().getMiddleware().getLogger().log("message");
```

---

## 18. Command Query Separation (CQS)

Every function should be either a **command** (does something, changes state, returns nothing) or a **query** (returns something, changes nothing). Never both.

### 18.1 Commands vs. Queries

```
// COMMAND — performs an action, no return value
function saveUser(user) {
    db.insert(user);
}

// QUERY — returns data, no side effects
function getUserById(id) {
    return db.find(id);
}

// BAD — does both: saves AND returns the saved user
// This hides the mutation behind a getter-looking interface
function saveAndGetUser(user) {
    db.insert(user);
    return db.find(user.id);   // side effect + return = violation
}

// GOOD — split them
saveUser(user);
const savedUser = getUserById(user.id);
```

### 18.2 Why This Matters

When a function looks like a query (has a return value, starts with `get`/`find`/`fetch`) but actually changes state, callers are surprised. Bugs that come from "I just read the value and something broke" are among the hardest to track down. Keep the contract clear.

### 18.3 Asking Should Never Change the Answer

A `getTotal()` method should never modify the cart. A `isValid()` method should never fix the data as a side effect. If calling a function twice in a row gives a different result, it's not a query — it's a disguised command.

---

## 19. Tell, Don't Ask

Tell objects what to do. Don't ask them for their state and then make decisions for them outside. Decision-making should live with the data it depends on.

### 19.1 The Pattern

```
// BAD — asking for state and deciding externally
if (account.getBalance() >= amount) {
    account.debit(amount);
} else {
    throw new Error("Insufficient funds");
}

// GOOD — tell the account to handle it
account.withdraw(amount);   // Account decides internally if it can
```

```
// BAD — asking light about its state to decide what to do
if (light.isOn()) {
    light.turnOff();
}

// GOOD — tell it what you want
light.turnOff();   // Light handles the no-op if already off
```

### 19.2 Where Logic Belongs

If a block of external code is inspecting an object's state to decide what to do with it, that logic almost certainly belongs inside the object itself. Moving it there reduces coupling, centralizes the decision, and makes the caller code cleaner.

---

## 20. Separation of Concerns

Every piece of code should have one concern and one concern only. Different concerns should live in different places and should not bleed into each other.

### 20.1 What a "Concern" Is

A concern is a distinct category of responsibility: data access, business logic, input validation, presentation, logging, error handling, routing, caching. These are separate concerns. When they live in the same function or file, every change to one risks breaking another.

### 20.2 The Classic Violation

```
// BAD — one function handles data access, business logic, AND presentation
function displayUserDashboard(userId) {
    const row = db.query(`SELECT * FROM users WHERE id = ${userId}`);  // data access
    const discount = row.purchases > 100 ? 0.2 : 0;                   // business logic
    document.getElementById("dashboard").innerHTML =                    // presentation
        `<h1>${row.name} — ${discount * 100}% discount</h1>`;
}

// GOOD — each concern in its own layer
function displayUserDashboard(userId) {
    const user = UserRepository.findById(userId);       // data access is elsewhere
    const discount = DiscountService.calculate(user);   // logic is elsewhere
    DashboardView.render(user, discount);               // presentation is elsewhere
}
```

### 20.3 Horizontal vs. Vertical Separation

Horizontal separation (layers): data access layer, service layer, presentation layer. Good for enforcing consistency across a large system.

Vertical separation (features): each feature is a self-contained slice that owns its own layers. Good for feature teams and independent deployability.

Both are valid. The key is that they are explicit and consistent, not an accident.

---

## 21. Pure Functions

A pure function always returns the same output for the same input, and produces no side effects. Pure functions are the easiest code to read, test, and reuse.

### 21.1 What Makes a Function Pure

```
// IMPURE — result depends on external state, modifies external state
let tax = 0.08;
function calculateTotal(price) {
    tax += 0.001;               // side effect: modifies external variable
    return price + price * tax; // depends on external mutable state
}

// PURE — same input always gives same output, nothing external is touched
function calculateTotal(price, taxRate) {
    return price + price * taxRate;
}
```

### 21.2 Isolate Impurity

You cannot eliminate all side effects — at some point you have to read from a database, write to a file, or call an API. The goal is to isolate impurity to the edges of the system, keeping the core logic pure.

```
// GOOD — pure core, impure edge
function getDiscountedPrice(price, memberSince) {
    const yearsAsMember = calculateYears(memberSince, Date.now());  // pure
    return applyDiscount(price, yearsAsMember);                      // pure
}

// The impure parts (database read, current time) are injected or live at the top
async function handlePriceRequest(userId, productId) {
    const user = await UserRepository.findById(userId);     // impure — I/O
    const product = await ProductRepository.findById(productId);  // impure — I/O
    return getDiscountedPrice(product.price, user.memberSince);   // pure core
}
```

### 21.3 Prefer Pure Where Possible

When writing a utility function, transformation, calculation, or validation, default to pure. Only reach for state when you have to. Pure functions compose, parallelize, cache, and test trivially.

---

## 22. Coupling & Cohesion

These two forces define the structure of healthy code. The goal is always **low coupling** and **high cohesion**.

### 22.1 Cohesion — Things That Belong Together Should Be Together

Cohesion measures how closely related the responsibilities inside a module are. High cohesion means everything in the file/class/function belongs there and works toward the same purpose.

```
// LOW COHESION — unrelated things dumped together
class Utils {
    formatDate(date) { ... }
    sendEmail(to, subject) { ... }
    calculateTax(price) { ... }
    parseCSV(file) { ... }
}

// HIGH COHESION — related things together, unrelated things separated
class DateFormatter { formatDate(date) { ... } }
class EmailService { send(to, subject) { ... } }
class TaxCalculator { calculate(price) { ... } }
class CsvParser { parse(file) { ... } }
```

### 22.2 Coupling — Things That Are Separate Should Stay Separate

Coupling measures how much one module depends on the internal details of another. Low coupling means a change to one module doesn't ripple through the rest of the codebase.

```
// HIGH COUPLING — UserService knows about the database structure directly
class UserService {
    getUser(id) {
        return db.query(`SELECT id, name, email FROM users WHERE id = ${id}`);
    }
}

// LOW COUPLING — UserService depends on an abstraction, not the database
class UserService {
    constructor(userRepository) {
        this.userRepository = userRepository;
    }
    getUser(id) {
        return this.userRepository.findById(id);
    }
}
```

### 22.3 The Test for Coupling

If changing one file forces you to change multiple other files that have nothing to do with your change, coupling is too high. The ideal: changing a module's internal implementation requires changes only inside that module.

---

## 23. Defensive Programming

Assume inputs can be wrong. Assume external systems can fail. Assume your own code has bugs. Write code that handles these realities explicitly rather than hoping they don't happen.

### 23.1 Validate at the Boundary

Every value entering your system from outside — API requests, user input, file reads, database rows — should be validated before it touches business logic. Internal function-to-function calls within a trusted module don't need the same level of paranoia.

```
// GOOD — validate at the entry point
function createUser(requestBody) {
    if (!requestBody.name || requestBody.name.trim() === "") {
        throw new ValidationError("Name is required");
    }
    if (!isValidEmail(requestBody.email)) {
        throw new ValidationError(`Invalid email: ${requestBody.email}`);
    }
    if (requestBody.age !== undefined && requestBody.age < 0) {
        throw new ValidationError("Age cannot be negative");
    }

    return UserRepository.create(requestBody);
}
```

### 23.2 Fail Fast, Fail Loud

When something is wrong, make it fail immediately with a clear error. Don't silently continue with bad data — it causes subtle, hard-to-trace bugs that surface far from the actual problem.

```
// BAD — continues with null, bug surfaces 20 lines later
function processOrder(order) {
    const user = findUser(order.userId);  // might return null
    const discount = user.membershipDiscount;  // null reference — bug surfaces here
}

// GOOD — fails immediately with context
function processOrder(order) {
    const user = findUser(order.userId);
    if (!user) throw new Error(`No user found for order ${order.id}, userId: ${order.userId}`);
    const discount = user.membershipDiscount;
}
```

### 23.3 Never Trust Return Values Without Checking

If a function can return null, undefined, an empty array, or an error object, handle all cases explicitly. Never assume the happy path.

### 23.4 Avoid Shotgun Defensive Checks Inside Logic

Defensive validation belongs at the boundary. Inside your core logic, if you've already validated at entry, you should be able to trust the data. Scattering null checks throughout internal functions is a sign the data flow is unclear, not that you need more checks.

---

## 24. Code Formatting & Consistency

Formatting is not aesthetic preference — it is communication. Inconsistent formatting forces the reader's brain to do extra work parsing structure instead of understanding logic.

### 24.1 One Style, No Exceptions

Pick a formatting standard and apply it everywhere without exception. Use a linter or auto-formatter to enforce it automatically so it requires zero thought. The specific choices matter far less than the consistency.

- JavaScript/TypeScript: Prettier + ESLint
- C#: .editorconfig + Roslyn analyzers
- Python: Black + Flake8
- Lua: StyLua

### 24.2 Vertical Whitespace as Punctuation

Blank lines separate logical sections within a function. Use them like paragraphs — group related statements together, separate distinct steps with a blank line.

```
// BAD — wall of code, no visual structure
function processCheckout(cart, user) {
    const validatedCart = validateCart(cart);
    const validatedUser = validateUser(user);
    const subtotal = calculateSubtotal(validatedCart.items);
    const discount = applyMemberDiscount(subtotal, validatedUser.tier);
    const tax = calculateTax(subtotal - discount);
    const total = subtotal - discount + tax;
    const order = createOrder(validatedUser, validatedCart, total);
    db.save(order);
    emailService.sendConfirmation(validatedUser.email, order);
    return order;
}

// GOOD — grouped by concern with whitespace as visual separation
function processCheckout(cart, user) {
    const validatedCart = validateCart(cart);
    const validatedUser = validateUser(user);

    const subtotal = calculateSubtotal(validatedCart.items);
    const discount = applyMemberDiscount(subtotal, validatedUser.tier);
    const tax = calculateTax(subtotal - discount);
    const total = subtotal - discount + tax;

    const order = createOrder(validatedUser, validatedCart, total);
    db.save(order);
    emailService.sendConfirmation(validatedUser.email, order);

    return order;
}
```

### 24.3 Horizontal Line Length

Keep lines under 100–120 characters. Long lines require horizontal scrolling and are harder to read side by side during code review. Break long expressions across multiple lines at logical boundaries.

```
// BAD — one enormous line
const eligibleUsers = users.filter(user => user.isActive && user.age >= 18 && user.country !== "US" && user.subscriptionTier > 1);

// GOOD — broken at logical points
const eligibleUsers = users.filter(user =>
    user.isActive &&
    user.age >= 18 &&
    user.country !== "US" &&
    user.subscriptionTier > 1
);
```

### 24.4 The Newspaper Rule — Top to Bottom Readability

Code should read like a newspaper article: the most important, high-level concept first, lower-level details below. In a file, put the public interface at the top and private helpers below. In a function, put the high-level flow first and delegate detail downward.

```
// GOOD — high-level orchestration at the top, details below
function processOrder(order) {
    validateOrder(order);
    const total = calculateTotal(order);
    chargeCustomer(order.customer, total);
    fulfillOrder(order);
}

// Private helpers below — called from above, never need to scroll up
function validateOrder(order) { ... }
function calculateTotal(order) { ... }
function chargeCustomer(customer, amount) { ... }
function fulfillOrder(order) { ... }
```

---

## 25. Type Safety & Explicit Contracts

Types are documentation that the compiler checks. Wherever your language supports it, use types to make the contract of every function explicit.

### 25.1 Avoid Primitive Obsession

Primitive obsession is using raw primitives (strings, numbers, booleans) where a named type or class would be more expressive and safer.

```
// BAD — all primitives, no meaning
function createUser(name: string, email: string, role: string, age: number) { ... }
createUser("Ethan", "ethan@x.com", "admin", 19);  // what does each argument mean?

// GOOD — typed, self-documenting
interface UserCreationParams {
    name: string;
    email: EmailAddress;
    role: UserRole;
    age: number;
}
function createUser(params: UserCreationParams) { ... }
```

### 25.2 Name Your Types

If you find yourself repeating the same shape in multiple places — `{ id: string, name: string, email: string }` — give it a name. It becomes a reusable contract.

```
// BAD — repeated anonymous shapes
function getUser(): { id: string; name: string; email: string } { ... }
function updateUser(user: { id: string; name: string; email: string }) { ... }

// GOOD — named contract
type User = { id: string; name: string; email: string };
function getUser(): User { ... }
function updateUser(user: User) { ... }
```

### 25.3 Make Invalid States Unrepresentable

Design your types so that impossible states can't be created. If the type system prevents the bug, you don't need runtime checks for it.

```
// BAD — both can be set at the same time, which is meaningless
type ApiResponse = {
    data: User | null;
    error: string | null;
}

// GOOD — only valid states are representable
type ApiResponse =
    | { status: "success"; data: User }
    | { status: "error"; error: string };
```

### 25.4 Avoid `any` / Untyped Escape Hatches

Using `any` (TypeScript), `object` (C#), or equivalent kills the type checker's ability to help you. Every `any` is a bug waiting to happen silently. If you genuinely don't know the type, use `unknown` and narrow it explicitly.

---

## 26. The Boy Scout Rule

Leave the code cleaner than you found it. Every time you touch a file — for a bug fix, a feature, a refactor — make at least one small improvement. Rename a confusing variable. Remove a dead comment. Extract a long condition into a named boolean. Over time, these tiny improvements compound into a dramatically cleaner codebase.

This is not about making sweeping changes during unrelated work. It's about the minimum: if you see something obviously wrong and it takes 30 seconds to fix, fix it.

---

## 27. Code Smells Reference

Code smells are patterns that signal likely problems. They don't always mean the code is wrong, but they're signals to investigate.

| Smell | Description | Fix |
|---|---|---|
| **Long Method** | Function over ~25-30 lines | Extract into smaller named functions |
| **Long Class / File** | Class doing too many things | Split by responsibility |
| **Primitive Obsession** | Using raw strings/numbers where types should be | Create named types or value objects |
| **Data Clumps** | Same group of variables appearing together everywhere | Extract them into a named type/class |
| **Feature Envy** | A function that uses another object's data more than its own | Move the function to the object it's most interested in |
| **Inappropriate Intimacy** | Two classes that know too much about each other's internals | Reduce access, add abstraction |
| **Shotgun Surgery** | One change requires edits in many unrelated files | Move related logic closer together |
| **Divergent Change** | One class changed for many different reasons | Split by the different reasons for change |
| **Switch Sprawl** | The same switch/if-else chain duplicated in multiple places | Replace with polymorphism |
| **Dead Code** | Code that is never executed | Delete it unconditionally |
| **Speculative Generality** | Abstractions built for futures that don't exist | Delete the unused flexibility |
| **Temporary Field** | A field that is only set in some scenarios | Extract into a separate class or pass as argument |
| **Message Chains** | `a.getB().getC().getD()` | Apply Law of Demeter — hide the chain |
| **Parallel Inheritance** | Every new subclass of X requires a new subclass of Y | Merge the hierarchies |
| **God Class / Object** | One class that knows and does everything | Break it up ruthlessly |
| **Comments Everywhere** | Comments explaining every line of code | Rewrite the code to be self-documenting |

---

## 28. Refactoring Signals

These are the immediate signals that code needs attention. When you encounter any of them, treat it as a stop sign — fix before moving forward.

| Signal | What It Means |
|---|---|
| Function over 30 lines | Likely does more than one thing |
| File over 400 lines | Likely has more than one responsibility |
| Nesting deeper than 2 levels | Use guard clauses or extract functions |
| More than 3 function arguments | Consider a config/options object |
| Copied and pasted code | Extract to a shared function |
| Comment explaining what (not why) | Rename the variable or function instead |
| Boolean parameter that changes behavior | Split into two functions |
| Magic number inline | Extract to a named constant |
| Function name containing "and" | Split into two functions |
| Condition that needs a comment to explain | Extract into a named boolean variable |
| Class with methods serving different concerns | Split the class |
| `else` after a `return` | Remove the `else` |
| Negative boolean name (`isNotLoaded`) | Flip it to positive (`isLoaded`) |
| Hardcoded string used for comparison | Extract to a named constant |
| Long method chains (`a.b().c().d()`) | Apply Law of Demeter |
| Function both does something and returns something | Apply Command Query Separation |
| External code inspecting an object's state to decide | Apply Tell Don't Ask — move logic inside the object |
| Same primitive group appearing in multiple places | Extract to a named type |
| `any` / untyped variable where a type is possible | Add a proper type |
| Abstraction that's only used in one place | Delete it (YAGNI) |
| Identical switch/if-else chain in multiple places | Replace with polymorphism |
| Function that uses another object's data more than its own | Move it to that other object |

---

*This guide synthesizes principles from CodeAesthetics, Clean Code (Robert C. Martin), The Pragmatic Programmer, and Refactoring (Martin Fowler). It is intentionally language-agnostic — all examples are illustrative pseudocode.*
