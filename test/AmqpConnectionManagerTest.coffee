chai       = require 'chai'
chai.use     require('chai-string')
{expect}   = chai

proxyquire = require 'proxyquire'
{FakeAmqp} = require './fixtures'
{wait}     = require '../src/helpers'

amqplib = new FakeAmqp()

AmqpConnectionManager = proxyquire '../src/AmqpConnectionManager', {
    'amqplib': amqplib
}

describe 'AmqpConnectionManager', ->
    amqp = null

    beforeEach ->
        amqplib.reset()

    afterEach ->
        amqp?.close()

    it 'should establish a connection to a broker', ->
        new Promise (resolve, reject) ->
            amqp = new AmqpConnectionManager('amqp://localhost')
            amqp.on 'connect', ({connection, url}) ->
                Promise.resolve().then ->
                    expect(url, 'url').to.equal 'amqp://localhost'
                    expect(connection.url, 'connection.url').to.equal 'amqp://localhost?heartbeat=5'

                .then resolve, reject

    it 'should work with a URL with a query', ->
        new Promise (resolve, reject) ->
            amqp = new AmqpConnectionManager('amqp://localhost?frameMax=0x1000')
            amqp.on 'connect', ({connection, url}) ->
                Promise.resolve().then ->
                    expect(connection.url, 'connection.url').to.equal 'amqp://localhost?frameMax=0x1000&heartbeat=5'

                .then resolve, reject

    it 'should reconnect to the broker if it can\'t connect in the first place', ->
        new Promise (resolve, reject) ->
            amqplib.deadServers = ['amqp://rabbit1']

            disconnectEventsSeen = 0

            # Should try to connect to rabbit1 first and be refused, and then succesfully connect to rabbit2.
            amqp = new AmqpConnectionManager(['amqp://rabbit1', 'amqp://rabbit2'], {heartbeatIntervalInSeconds: 0.01})

            amqp.on 'disconnect', ({err}) ->
                disconnectEventsSeen++
                amqplib.failConnections = false

            amqp.on 'connect', ({connection, url}) ->
                Promise.resolve().then ->
                    expect(disconnectEventsSeen).to.equal 1

                    # Verify that we round-robined to the next server, since the first was unavilable.
                    expect(url, 'url').to.equal 'amqp://rabbit2'
                    expect(connection.url, 'connection.url').to.startWith url

                .then resolve, reject

    it 'should reconnect to the broker if the broker disconnects', ->
        new Promise (resolve, reject) ->
            amqp = new AmqpConnectionManager('amqp://localhost', {heartbeatIntervalInSeconds: 0.01})
            connectsSeen = 0

            amqp.once 'connect', ({connection, url}) ->
                connectsSeen++
                # Murder the broker on the first connect
                amqplib.kill()

                amqp.once 'connect', ({connection, url}) ->
                    # Make sure we connect a second time
                    connectsSeen++
                    Promise.resolve().then ->
                        expect(connectsSeen).to.equal 2

                    .then resolve, reject

    it 'should know if it is connected or not', ->
        new Promise (resolve, reject) ->
            amqp = new AmqpConnectionManager('amqp://localhost')
            expect(amqp.isConnected()).to.be.false

            amqp.on 'connect', ({connection, url}) ->
                Promise.resolve().then ->
                    expect(amqp.isConnected()).to.be.true

                .then resolve, reject

    it 'should create and clean up channel wrappers', ->
        amqp = new AmqpConnectionManager('amqp://localhost')
        channel = amqp.createChannel {name: 'test-chan'}

        # Channel should register with connection manager
        expect(amqp._channels.length, 'registered channels').to.equal 1
        expect(amqp.listeners('connect').length, 'connect listners').to.equal 1
        expect(amqp.listeners('disconnect').length, 'disconnect listners').to.equal 1

        # Closing the channel should remove all listeners and de-register the channel
        channel.close()
        expect(amqp._channels.length, 'registered channels after close').to.equal 0
        expect(amqp.listeners('connect').length, 'connect listners after close').to.equal 0
        expect(amqp.listeners('disconnect').length, 'disconnect listners after close').to.equal 0

    it 'should clean up channels on close', ->
        amqp = new AmqpConnectionManager('amqp://localhost')
        channel = amqp.createChannel {name: 'test-chan'}

        # Channel should register with connection manager
        expect(amqp._channels.length, 'registered channels').to.equal 1
        expect(amqp.listeners('connect').length, 'connect listners').to.equal 1
        expect(amqp.listeners('disconnect').length, 'disconnect listners').to.equal 1

        # Closing the connection should remove all listeners and de-register the channel
        amqp.close()
        expect(amqp._channels.length, 'registered channels after close').to.equal 0
        expect(amqp.listeners('connect').length, 'connect listners after close').to.equal 0
        expect(amqp.listeners('disconnect').length, 'disconnect listners after close').to.equal 0

    it 'should not reconnect after close', ->
        new Promise (resolve, reject) ->
            amqp = new AmqpConnectionManager('amqp://localhost', {heartbeatIntervalInSeconds: 0.01})
            connectsSeen = 0

            amqp.on 'connect', -> connectsSeen++

            amqp.once 'connect', ({connection, url}) ->
                Promise.resolve()
                .then ->
                    # Close the manager
                    amqp.close()

                    # Murder the broker on the first connect
                    amqplib.kill()

                    # Wait a moment
                    wait(50)

                .then ->
                    # Make sure didn't see a second connect
                    expect(connectsSeen).to.equal 1

                .then resolve, reject
