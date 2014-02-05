# Stompede

[![Build Status](https://travis-ci.org/Burgestrand/stompede.png?branch=master)](https://travis-ci.org/Burgestrand/stompede)
[![Dependency Status](https://gemnasium.com/Burgestrand/stompede.png)](https://gemnasium.com/Burgestrand/stompede)
[![Code Climate](https://codeclimate.com/github/Burgestrand/stompede.png)](https://codeclimate.com/github/Burgestrand/stompede)
[![Gem Version](https://badge.fury.io/rb/stompede.png)](http://badge.fury.io/rb/stompede)

STOMP over WebSockets for Ruby. Stompede aims to supply:

- A STOMP message parser.
- A STOMP message generator.
- A STOMP protocol WebSocket server.

## Usage

TODO: Write usage instructions here.

### Guarantees

- `open` for a client will always receive a matching `close` (TODO: exceptions?)
- `subscribe` with a subscriber will always receive a matching `unsubscribe` (TODO: exceptions?)
- `connect` and `disconnect` may not be called for a client, for example if it
  disconnects instantly.
- All messages for a single client are processed in FIFO order serially.
- `close` may not be called immediately when a client disconnects, but some
  time later.
- Once `close` has been called, no further messages from the client will be
  processed.

- Objects representing

### Constraints

- Clients may not subscribe to the same destination twice.
- Transactions are not (yet) supported.

### Sane defaults

- SEND frame with a receipt from the client will receive a RECEIPT when the callback succeeds, and an ERROR in case it caused an exception. (assuming the client is still connected)

## Development

Development should be ez.

``` bash
git clone git@github.com:Burgestrand/stompede.git # git, http://git-scm.com/
cd stompede
brew bundle # Homebrew, http://brew.sh/
bundle install # Bundler, http://bundler.io/
rake # compile state machine, run test suite
```

A few notes:

- I develop on a Mac. YMMV.
- Native dependencies are listed in the Brewfile.
- The stomp message parser is written in [Ragel](http://www.complang.org/ragel/).
- Graphviz is used to visualize the Ragel state machine.
- Most rake tasks will compile the state machine anew if needed.

## Contributing

1. Fork it on GitHub (<http://github.com/Burgestrand/stompede/fork>).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Follow the [Development](#development) instructions in this README.
4. Create your changes, please add tests.
5. Commit your changes (`git commit -am 'Add some feature'`).
6. Push to the branch (`git push origin my-new-feature`).
7. Create new pull request on GitHub.
