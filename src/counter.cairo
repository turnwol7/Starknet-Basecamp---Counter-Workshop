#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}

#[starknet::contract]
mod counter_contract {
    use super::ICounter;
    use starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Embed the Ownable component's logic
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // Embed the Ownable component's internal logic
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        value: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_value: u32,
        kill_switch: ContractAddress,
        initial_owner: ContractAddress
    ) {
        self.counter.write(initial_value);
        self.kill_switch.write(kill_switch);
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl Counter of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            // Assert that the caller is the owner
            self.ownable.assert_only_owner();

            let kill_switch_dispatcher = IKillSwitchDispatcher { contract_address: self.kill_switch.read() };
            
            assert!(!kill_switch_dispatcher.is_active(), "Kill Switch is active");

            let current_count = self.counter.read();
            let new_count = current_count + 1;
            self.counter.write(new_count);
            
            self.emit(Event::CounterIncreased(CounterIncreased { value: new_count }));
        }
    }

    
}