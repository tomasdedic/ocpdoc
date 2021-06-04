## Eventhub concept
Myšlenka je použít **Evenhub** jako store pro logy z OCP a pro transport těchto logů použít FluentD.
Koncept Eventhubu je dost podobný kafka konceptu, slovníček terminologie je zde:

```sh
# eventhub vs kafka
Kafka Concept vs Event Hubs Concept
Cluster        <---->     Namespace
Topic          <---->     Event Hub
Partition      <---->     Partition
Consumer Group <---->     Consumer Group
Offset         <---->     Offset
```

### EventHub sizing
Minimální jednotka ThruPut Unit (TU) - znamená 1 MB/Sec(inbound) nebo 1000msgs/sec (co z toho bude první) a definuje se pro celý **Namespace**. TU se dá dynamicky měnit.  
Zároveň každý **EventHub** má určité množství partitions (defaultně jednu) - jde definovat pouze při vytvoření a 1 partition vlastně dělá CAP pro daný EvenHub 1MB/Sec(inbound) nebo 1000msgs/sec (co z toho bude první).  
Maximální velikost zprávy kterou EvenHub akceptuje je 1MB.   
Zároveň se mi zdá že je limitováno množství zpráv v jednom "record batch" ale v oficiální dokumentaci jsem nic kolem toho nenašel.
  
Pokud je tento limit přesažen vrací se chyba:
+ message_too_long
nebo
+ connection reset

## FluentD with eventhub aspect
Pro konfiguraci fluentD použijeme [kafka2 plugin](https://github.com/fluent/fluent-plugin-kafka)  

fluentD kafka output sample configuration:

```sh
#fluent.conf
# oc get cm fluentd -o yaml|yq e '(.data.fluent*)' -|vim -
    <label @LOGS>
      <match **>
        @type copy
        <store>
          @type kafka2
          brokers log.servicebus.windows.net:9093
          # get some response from eventhub, usefull for debug
          get_kafka_client_log true
          ssl_ca_certs_from_system true
          default_topic 'log.oaz1_test_in'
          username $ConnectionString
          password "Endpoint=sb://log.servicebus.windows.net/;SharedAccessKeyName=ack;SharedAccessKey=jjwYrmVQkk22fuXsadCQTHNSDrSW1wTSfq8rOOCkEMc="
          # topic settings
          <buffer topic>
            @type file
            path '/var/lib/fluentd/logs'
            flush_interval 5s
            flush_thread_count 2
            #limit queues
            queued_chunks_limit_size "#{ENV['BUFFER_QUEUE_LIMIT'] || '32' }"
            #Once the total size of stored buffer reached this threshold, all append operations will fail with error (and data will be lost)
            total_limit_size "#{ENV['TOTAL_LIMIT_SIZE'] ||  8589934592 }" #8G
            chunk_limit_size 819200
            overflow_action throw_exception
            retry_type exponential_backoff
            retry_wait 5
            retry_exponential_backoff_base 4
            retry_max_interval 600
            retry_forever
          </buffer>
          max_send_retries 2
          required_acks -1
          max_send_limit_bytes 1000000
          <format>
            @type json
          </format>

        </store>
      </match>
    </label>


```
### Important Config Options
```sh
chunk_limit_size 819200 #800KB
```
Jelikož pro eventhub platí **message.max.bytes=1048576** musíme použít menší chunk než 1MB. 
> chunk: A buffer plugin uses a chunk as a lightweight container, and fills it with events incoming from input sources. If a chunk becomes full, then it gets "shipped" to the destination.
> zároveň pro kafka2 plugin platí: kafka2 uses one buffer chunk for one record batch.

```sh
max_send_limit_bytes 1000000
```
> max_send_limit_bytes - default: nil - Max byte size to send message to avoid MessageSizeTooLarge. For example, if you set 1000000(message.max.bytes in kafka), Message more than 1000000 byes will be dropped.
Trochu sem se nechal zmýlit a myslel jsem že je to limit pro velikost zprávy.  
  
Chceme abychom vždy zprávy odeslali ale pokud je cíl nedostupný nastavíme exponenciální zvyšování času mezi pokusy až do hodnoty 10min.
```sh
# sending options 
max_send_retries 2 #send 2x to leader direct
#A chunk can fail to be written out to the destination for a number of reasons. The network can go down, or the traffic volumes can exceed the capacity of the destination node. To handle such common failures gracefully, buffer plugins are equipped with a built-in retry mechanism.
retry_type exponential_backoff
retry_max_interval 600 #10 min maximálně pro exponent
retry_exponential_backoff_base 4
retry_wait 5 #first wait 5..20..80...
retry_forever #never give up
```

Zároveň nastává problém s velikostí chunku pro audit (WriteBody).  
Jelikož velikost chunku poslaného do eventhubu může být 1MB ale zároveň velikost vytvořeného objektu(tedy auditovaného) je také max 1MB. Chunk se však načítá paralelně a prostě není schopen to okamžitě utnout.  
Pro **audit logy** je tedy zdá být vhodná konfigurace bufferu, kde limitujeme množství zpráv a co nejčastěji děláme **flush**
```sh
# audit log transport 
            flush_interval 1s
            flush_thread_count 4
            queued_chunks_limit_size "#{ENV['BUFFER_QUEUE_LIMIT'] || '32' }"
            total_limit_size "#{ENV['TOTAL_LIMIT_SIZE'] ||  8589934592 }" #8G
            # chunk_limit_size "#{ENV['BUFFER_SIZE_LIMIT'] || '8m'}"
            chunk_limit_size 819200
            chunk_full_threshold 0.9
            chunk_limit_records 10
```


### DEBUG transport to EventHub
Pro kafka clienta je dobré použít, jinak je log dost hluchý
```sh
get_kafka_client_log true
```
pro samotný fluentD pak upravit fluent.conf
```sh
    <system>
      log_level "#{ENV['LOG_LEVEL'] || 'warn'}"
    </system>
# klasicky fatal, error, warn, info, debug trace
# přičemž level info už je dostatečně obsáhlý
```

