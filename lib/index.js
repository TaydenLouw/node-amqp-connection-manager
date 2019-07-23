"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.connect = connect;
exports.default = void 0;

var _AmqpConnectionManager = _interopRequireDefault(require("./AmqpConnectionManager"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function connect(urls, options, logger) {
  return new _AmqpConnectionManager.default(urls, options, logger);
}

const amqp = {
  connect
};
var _default = amqp;
exports.default = _default;
//# sourceMappingURL=index.js.map