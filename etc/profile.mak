export ZETA_HOME=$HOME/workspace/zeta
export ZERO_HOME=$HOME/workspace/zero
export PERL5LIB=$ZETA_HOME/lib::$ZERO_HOME/lib
export PLUGIN_PATH=$ZERO_HOME/plugin
export PATH=$ZERO_HOME/bin:$ZERO_HOME/sbin:$ZETA_HOME/bin:$PATH

# 节点编号
export ZERO_ID=0;

export DB_NAME=zdb_dev
export DB_USER=ypinst
export DB_PASS=ypinst
export DB_SCHEMA=ypinst
alias dbc='db2 connect to $DB_NAME user $DB_USER using $DB_PASS'

export DB_NAME_BKE=zdb_dev
export DB_USER_BKE=ypinst
export DB_PASS_BKE=ypinst
export DB_SCHEMA_BKE=ypinst
alias dbbc='db2 connect to $DB_NAME_BKE user $DB_USER_BKE using $DB_PASS_BKE'

alias cdl='cd $ZERO_HOME/log';
alias cdd='cd $ZERO_HOME/data';
alias cdlb='cd $ZERO_HOME/lib/Zero';
alias cdle='cd $ZERO_HOME/libexec';
alias cdb='cd $ZERO_HOME/bin';
alias cdsb='cd $ZERO_HOME/sbin';
alias cdc='cd $ZERO_HOME/conf';
alias cde='cd $ZERO_HOME/etc';
alias cdt='cd $ZERO_HOME/t';
alias cdh='cd $ZERO_HOME';
alias cdtb='cd $ZERO_HOME/sql/table';

