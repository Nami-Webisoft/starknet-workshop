#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState) -> ();
}

#[starknet::contract]
pub mod counter_contract {
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::OwnableComponent;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};

    component!(path:    OwnableComponent,
               storage: ownable_component,
               event:   OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableComponentGeneric = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableComponentInternal = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    // The event enum must be annotated with the `#[event]` attribute.
    // It must also derive at least the `Drop` and `starknet::Event` traits.
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    pub struct CounterIncreased {
        value: u32
    }

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable_component: OwnableComponent::Storage
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, initial_value: u32, kill_switch_address: ContractAddress, owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch_address);
        self.ownable_component.initializer(owner);
    }

    #[abi(embed_v0)]
    impl counter_contract of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            return self.counter.read();
        }

        fn increase_counter(ref self: ContractState) -> () {
            self.ownable_component.assert_only_owner();

            let kill_switch_dispatcher = IKillSwitchDispatcher {
             contract_address: self.kill_switch.read()
              };

            assert!(!kill_switch_dispatcher.is_active(), "Kill Switch is active");

            self.counter.write(self.counter.read() + 1);
            self.emit(Event::CounterIncreased(CounterIncreased {
                value: self.counter.read()
            }));
        }
    }
}
