package Zero::Bank;
use strict;
use warnings;
use POE::Session;
use POE::Wheel::ReadWrite;
use POE::Filter::Block;
use POE::Filter::HTTP::Parser;
use Zeta::Codec::Frame qw/ascii_n binary_n/;

#
#  name   => '银行名称',
#  host   => '银行IP',
#  port   => '银行端口',
#  codec  => '过滤器',
#  proc   => \%proc,
#
sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;

    # 子类初始化
    return $self->_init();
}

#
# 启动银行session
# $self->spawn($zcfg, $logger)
#
sub spawn {

    my ($self, $zcfg, $logger) = @_;

    # 日志 + 应用配置
    $self->{logger} = $logger->clone('bank-' . $self->{name} . '.log');
    $self->{zcfg}   = $zcfg;

    # 子进程下的初始化
    $self->_setup();

    POE::Session->create(
        object_states => [ 
            $self => { 
               'on_tran'        => 'on_tran',           # 收到tran的请求
               'on_bank_packet' => 'on_bank_packet',    # 收到银行的应答报文
               'on_bank_error'  => 'on_bank_error',     #
               'on_chnl_error'  => 'on_chnl_error',     # 
            },
        ],
        inline_states => {
            _start => sub {
                $_[KERNEL]->alias_set($self->{name});
            },
        },
    );
};

#
# 收到交易
#
sub on_tran {

    my $self = $_[OBJECT];
    my $tran = $_[ARG0];
    
    $self->{logger}->debug("收到交易:\n" . Data::Dump->dump($tran));
   
    # 连接银行
    $self->{logger}->debug("连接银行[$self->{host}:$self->{port}]");
    my $bsock = IO::Socket::INET->new(
       PeerAddr => $self->{host},
       PeerPort => $self->{port},
       Proto    => 'tcp',
    );

    # codec顾虑器配置
    my $filter;
    my $fargs;
    if ($self->{codec} =~ /ascii\s+(\d+)/) {
        $filter = 'POE::Filter::Block';
        $fargs  = [ LengthCodec => &ascii_n($1) ];
    } 
    elsif($self->{codec} =~ /binary\s+(\d+)/) {
        $filter = 'POE::Filter::Block';
        $fargs  = [ LengthCodec => &binary_n($1) ];
    }
    elsif($self->{codec} =~ /http/) {
        $filter = 'POE::Filter::HTTP::Parser';
        $fargs  = [ ];
    }

    my $wheel = POE::Wheel::ReadWrite->new(
        Handle       => $bsock,
        Filter       => $filter->new(@$fargs),
        InputEvent   => 'on_bank_packet',
        ErrorEvent   => 'on_bank_error',
        FlushedEvent => 'on_bank_flush',
    );

    # 渠道请求 -->  银行请求
    my $breq = $self->{proc}{$tran->{b_tcode}}{c2b}->($self, $tran);
    $self->{logger}->debug("breq:".Data::Dump->dump($breq));
    $tran->{breq} = $breq;
    $tran->{bid}  = $wheel->ID();
    # 保存到堆: 通道+交易
    $_[HEAP]{bank}{$wheel->ID()} = {
        wheel => $wheel, 
        tran  => $tran,
    };

    # 银行请求报文打包
    my $packet = $self->pack($breq);
   
    # 发送给银行
    $self->{logger}->debug_hex("发送银行报文>>>>>>>>:", $packet); 
    $wheel->put($packet);
}


#
# 收到银行数据
#
sub on_bank_packet {
    my $self   = $_[OBJECT];
    my $packet = $_[ARG0];
    my $bid    = $_[ARG1];

    $self->{logger}->debug_hex("收到银行报文<<<<<<<<:",  $packet);

    # 删除堆上:  通道+交易
    my $t = delete $_[HEAP]{bank}{$bid};
    my $tran = $t->{tran};

    # 银行报文 ---> 银行应答
    my $bres = $self->unpack($packet);
    $tran->{bres} = $bres;
  
    ################################################# 
    # 银行应答 ---> 渠道应答, (插入数据库, 提交)
    ################################################# 
    my $cres = $self->{proc}{$tran->{b_tcode}}{b2c}->($self, $tran);

    # 直接发送到chnl进程
    $tran->{cres} = $cres;
    $_[KERNEL]->post($t->{tran}->{chnl}, 'on_chnl_res', $tran);

    return 1;
}

#
# 银行断开连接
#
sub on_bank_error {

    my $self = $_[OBJECT];
    my $id   = $_[ARG3];
    $self->{logger}->debug("on_bank_error called[$id], 释放资源, 通知渠道端");
    
    # 释放银行端资源
    my @r = keys %{$_[HEAP]{bank}};
    $self->{logger}->debug("释放[$id]资源[前]的堆栈情况:[@r]");
    
    my $t = delete $_[HEAP]{bank}->{$id};
    
    @r = keys %{$_[HEAP]{bank}};
    $self->{logger}->debug("释放[$id]资源[后]的堆栈情况:[@r]");

    # 通知渠道端释放资源
    $_[KERNEL]->post($t->{tran}{chnl}, 'on_bank_error', $t->{tran}{cid});
    
    return 1;
}

#
# 渠道断开连接
#
sub on_chnl_error {

    my $self = $_[OBJECT];
    my $id   = $_[ARG0];
    $self->{logger}->debug("on_chnl_error called[$id], 释放资源");
    
    # 释放银行端资源
    my @r = keys %{$_[HEAP]{bank}};
    $self->{logger}->debug("释放[$id]资源[前]的堆栈情况:[@r]");
    
    my $t = delete $_[HEAP]{bank}{$id};
    
    @r = keys %{$_[HEAP]{bank}};
    $self->{logger}->debug("释放[$id]资源[后]的堆栈情况:[@r]");
    
    return 1;
}

# 子类实现如下接口
sub _init  { warn "_init to be implemented by Derived class"; }   # 子类实现
sub _setup { warn "_setup to be implemented by child process"; }  # 子进程db相关设置
sub pack   { warn "pack to be implemented by Derived class"; }    # 银行报文解包 
sub unpack { warn "unpack to be implemented by Derived class"; }  # 银行报文打包 

1;
