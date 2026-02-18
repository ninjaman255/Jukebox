# Async, EventEmitter & Utility Modules

*A lightweight asynchronous programming toolkit for Lua, inspired by JavaScript's async/await, Promises, and event-driven patterns.*

---

## 📦 Modules Overview

| Module | Purpose |
|------|--------|
| **async.lua** | Promise system and async/await helpers |
| **event-emitter.lua** | Event-driven architecture with async iterators |
| **utility.lua** | Convenience helpers and shortcuts |

---

## 🔁 async.lua

### `Async.create_promise(executor)`

**Purpose**  
Creates a new **Promise** object for asynchronous operations.

**Parameters**  
- `executor` *(function)* — Function with signature `(resolve, reject)`

**Returns**  
- `Promise` — Tracks state and handlers

**How it works**
- Initializes a promise in a `pending` state  
- Provides `resolve(...)` and `reject(error)` callbacks  
- Transitions state on completion and invokes handlers  
- Catches executor errors and automatically rejects  

---

### `Async.promisify(coroutine_func)`

**Purpose**  
Converts a coroutine-based function into a Promise.

**Parameters**  
- `coroutine_func` *(function)* — Returns a coroutine

**Returns**  
- `Promise` — Resolves when coroutine completes

**How it works**
- Wraps coroutine execution inside a promise  
- Advances coroutine via `coroutine.resume()`  
- Awaits yielded promises automatically  
- Resolves with final return value or rejects on error  

---

### `Async.await(promise_or_iterator)`

**Purpose**  
Awaits a Promise or async iterator inside a coroutine.

**Parameters**  
- `promise_or_iterator` *(Promise | Iterator)*

**Returns**  
- Resolved value(s)

**How it works**
- Detects promises vs iterators  
- Returns immediately if settled  
- Yields coroutine until resolution  
- Supports async iteration over events  

---

### `Async.run(main_function)`

**Purpose**  
Starts execution of an async function.

**Parameters**  
- `main_function` *(coroutine function)*

**Returns**  
- `Promise` — Represents async execution

**How it works**
- Wraps function in coroutine  
- Converts to promise via `promisify()`  
- Returns promise for chaining  

---

### `Async.create_validator(expected_values, error_message)`

**Purpose**  
Creates a validation helper for argument checking.

**Parameters**
- `expected_values` *(table)* — Expected argument values  
- `error_message` *(string)* — Error to throw on mismatch  

**Returns**
- `function` — Validator

**How it works**
- Compares arguments against expectations  
- Throws error if any mismatch is detected  

---

## 📣 event-emitter.lua

### `EventEmitter.new()`

**Purpose**  
Creates a new EventEmitter instance.

**Returns**
- `EventEmitter`

**How it works**
- Initializes listener tables  
- Tracks iterators and destroyed state  

---

### `EventEmitter:on(event, callback)`

Registers a **persistent** listener.

| Parameter | Type | Description |
|---------|------|-------------|
| `event` | string | Event name |
| `callback` | function | Listener function |

---

### `EventEmitter:once(event, callback)`

Registers a **one-time** listener removed after first trigger.

---

### `EventEmitter:on_any(callback)`

Registers a persistent listener for **all events**.

---

### `EventEmitter:on_any_once(callback)`

Registers a one-time listener for **all events**.

---

### `EventEmitter:emit(event, ...)`

**Purpose**  
Emits an event with arguments.

**How it works**
- Invokes event-specific listeners  
- Invokes any-event listeners  
- Resolves async iterators  
- Cleans up one-time handlers  

---

### `EventEmitter:remove_listener(event, callback)`

Removes a specific event listener.

---

### `EventEmitter:remove_on_any_listener(callback)`

Removes a global listener.

---

### `EventEmitter:async_iter(event)`

**Purpose**  
Creates an async iterator for a specific event.

**Returns**
- `iterator function` (used with `Async.await()`)

**How it works**
- Buffers incoming events  
- Yields when no data is available  
- Auto-cleans on close  

---

### `EventEmitter:async_iter_all()`

Async iterator for **all events** (event name included).

---

### `EventEmitter:destroy()`

**Purpose**  
Cleans up all listeners and iterators.

**How it works**
- Clears listener tables  
- Resolves waiting iterators  
- Prevents further use  

---

## 🛠 utility.lua

### `Utility.create_event_test()`

**Purpose**  
Demonstrates async event listening patterns.

**Returns**
- `emitter`
- `start_listening` function

---

### `Utility.resolve_multi(...)`

Creates a promise resolving with **multiple values**.

---

### `Utility.event_to_promise(emitter, event_name)`

Converts a single event emission into a Promise.

---

## 🔗 Shortcut Properties

Utility re-exports Async helpers:

```lua
Utility.create_promise = Async.create_promise
Utility.promisify     = Async.promisify
Utility.await         = Async.await
Utility.run           = Async.run
```

---

## 🧠 Key Patterns

- **Promise Pattern** — JS-style `.then()` chaining  
- **Async/Await** — Coroutine-based synchronous flow  
- **Event-Driven** — Reactive architecture  
- **Async Iterators** — Stream-based event handling  

---

> ✨ This system enables modern asynchronous programming in Lua by combining coroutines, promises, and event-driven design.
