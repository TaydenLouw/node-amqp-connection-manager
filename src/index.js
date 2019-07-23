import AmqpConnectionManager from './AmqpConnectionManager';

export function connect(urls, options, logger) {
    return new AmqpConnectionManager(urls, options, logger);
}

const amqp = {
    connect
};

export default amqp;
