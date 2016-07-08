
application-myshard{
    // listen a port for mysql-cli
    porxy-mysql-tcp-potc{
        hold-client-connection-poll{}
    }

    connect-2-mysql-backen{
        sql-parser{}
        switch(sql-type){
            mysql-backen = get-mysql-backen-from( config{} )
            result = execute-sql-on(mysql-backen);
            write-to-client-connection(result);
        }
        hold-backen-connection-pool{}
        close-client-connect-when-timeout{}
    }

    config{
        new(){ parse-config-file()}
        rule-of-shard-mysql{}
    }

}