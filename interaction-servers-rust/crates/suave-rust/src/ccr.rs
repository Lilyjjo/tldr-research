// todo: split into files

use alloy::{
    consensus::{
        SignableTransaction,
        Signed,
        Transaction,
    },
    primitives::{
        self,
        Address,
        Bytes,
        ChainId,
        FixedBytes,
        Signature,
        TxKind,
        U256,
    },
    rpc::types::eth::TransactionRequest,
};
use alloy_rlp::{
    Encodable,
    RlpEncodable,
};
use eyre::{
    eyre,
    Ok,
    Result,
};
use serde::{
    Deserialize,
    Serialize,
};

enum CCTypes {
    ConfidentialComputeRecord = 0x42,
    ConfidentialComputeRequest = 0x43,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct ConfidentialComputeRequest {
    pub confidential_compute_record: ConfidentialComputeRecord,
    pub confidential_inputs: Bytes,
}

impl ConfidentialComputeRequest {
    pub fn new(
        mut confidential_compute_record: ConfidentialComputeRecord,
        confidential_inputs: Bytes,
    ) -> Self {
        let ci_hash = primitives::keccak256(&confidential_inputs);
        confidential_compute_record.set_confidential_inputs_hash(ci_hash);

        Self {
            confidential_compute_record,
            confidential_inputs,
        }
    }

    pub fn rlp_encode(&self) -> Result<Bytes> {
        let cc_record = &self.confidential_compute_record;
        if cc_record.has_missing_field() {
            return Err(eyre!("Missing fields"));
        }
        let rlp_encoded = encode_with_prefix(
            CCTypes::ConfidentialComputeRequest as u8,
            CcRequestRlp::from(self),
        );

        Ok(rlp_encoded)
    }

    pub fn hash(&self) -> FixedBytes<32> {
        let rlp_encoded = encode_with_prefix(
            CCTypes::ConfidentialComputeRecord as u8,
            CcrHashingParams::from(self),
        );
        let hash = primitives::keccak256(&rlp_encoded);
        hash
    }
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct ConfidentialComputeRecord {
    nonce: u64,
    to: Address,
    gas: u64,
    gas_price: U256,
    value: U256,
    data: Bytes,
    execution_node: Address,
    chain_id: u64,
    confidential_inputs_hash: Option<FixedBytes<32>>,
    v: Option<u8>,
    r: Option<U256>,
    s: Option<U256>,
}

impl ConfidentialComputeRecord {
    pub fn from_tx_request(tx_req: TransactionRequest, execution_node: Address) -> Self {
        // todo: make this more restrictive (in case someone forgets to set a field eg chain_id)
        // todo: use Resutl
        Self {
            nonce: tx_req.nonce.unwrap_or(0),
            to: tx_req.to.unwrap_or(Address::ZERO),
            gas: tx_req
                .gas
                .map(|g| g.try_into().expect("Overflowing gas param"))
                .unwrap_or(0),
            gas_price: tx_req.gas_price.unwrap_or(U256::ZERO),
            value: tx_req.value.unwrap_or(U256::ZERO),
            data: tx_req.input.input.unwrap_or(Bytes::new()),
            execution_node,
            chain_id: tx_req.chain_id.unwrap_or(0),
            confidential_inputs_hash: None,
            v: None,
            r: None,
            s: None,
        }
    }

    pub fn set_confidential_inputs_hash(&mut self, confidential_inputs_hash: FixedBytes<32>) {
        self.confidential_inputs_hash = Some(confidential_inputs_hash);
    }

    pub fn set_sig(&mut self, v: u8, r: U256, s: U256) {
        self.v = Some(v);
        self.r = Some(r);
        self.s = Some(s);
    }

    pub fn has_missing_field(&self) -> bool {
        self.confidential_inputs_hash.is_none()
            || self.r.is_none()
            || self.s.is_none()
            || self.v.is_none()
    }
}

#[derive(Debug, RlpEncodable, PartialEq, Serialize, Deserialize)]
struct CcRecordRlp {
    nonce: u64,
    gas_price: U256,
    gas: u64,
    to: Address,
    value: U256,
    data: Bytes,
    execution_node: Address,
    confidential_inputs_hash: FixedBytes<32>,
    chain_id: u64,
    v: u8,
    r: U256,
    s: U256,
}

#[derive(Debug, RlpEncodable, PartialEq, Serialize, Deserialize)]
struct CcRequestRlp {
    request: CcRecordRlp,
    confidential_inputs: Bytes,
}

impl From<&ConfidentialComputeRecord> for CcRecordRlp {
    fn from(ccr: &ConfidentialComputeRecord) -> Self {
        Self {
            nonce: ccr.nonce,
            gas_price: ccr.gas_price,
            gas: ccr.gas,
            to: ccr.to,
            value: ccr.value,
            data: ccr.data.clone(),
            execution_node: ccr.execution_node,
            confidential_inputs_hash: ccr
                .confidential_inputs_hash
                .expect("Missing confidential_inputs_hash"),
            chain_id: ccr.chain_id,
            v: ccr.v.expect("Missing v field"),
            r: ccr.r.expect("Missing r field"),
            s: ccr.s.expect("Missing s field"),
        }
    }
}

impl From<&ConfidentialComputeRequest> for CcRequestRlp {
    fn from(ccr: &ConfidentialComputeRequest) -> Self {
        Self {
            request: (&ccr.confidential_compute_record).into(),
            confidential_inputs: ccr.confidential_inputs.clone(),
        }
    }
}

#[derive(Debug, RlpEncodable, PartialEq, Serialize, Deserialize)]
struct CcrHashingParams {
    execution_node: Address,
    confidential_inputs_hash: FixedBytes<32>,
    nonce: u64,
    gas_price: U256,
    gas: u64,
    to: Address,
    value: U256,
    data: Bytes,
}

impl From<&ConfidentialComputeRequest> for CcrHashingParams {
    fn from(ccr: &ConfidentialComputeRequest) -> Self {
        Self {
            execution_node: ccr.confidential_compute_record.execution_node,
            confidential_inputs_hash: ccr
                .confidential_compute_record
                .confidential_inputs_hash
                .expect("Missing confidential_inputs_hash"),
            nonce: ccr.confidential_compute_record.nonce,
            gas_price: ccr.confidential_compute_record.gas_price,
            gas: ccr.confidential_compute_record.gas,
            to: ccr.confidential_compute_record.to,
            value: ccr.confidential_compute_record.value,
            data: ccr.confidential_compute_record.data.clone(),
        }
    }
}

fn encode_with_prefix<T: Encodable>(prefix: u8, item: T) -> Bytes {
    let mut buffer = vec![prefix];
    item.encode(&mut buffer);
    Bytes::from(buffer)
}

impl Transaction for ConfidentialComputeRequest {
    fn input(&self) -> &[u8] {
        self.confidential_compute_record.data.as_ref()
    }

    fn to(&self) -> TxKind {
        TxKind::Call(self.confidential_compute_record.to)
    }

    fn value(&self) -> U256 {
        self.confidential_compute_record.value
    }

    fn chain_id(&self) -> Option<ChainId> {
        Some(self.confidential_compute_record.chain_id)
    }

    fn nonce(&self) -> u64 {
        self.confidential_compute_record.nonce
    }

    fn gas_limit(&self) -> u64 {
        self.confidential_compute_record.gas
    }

    fn gas_price(&self) -> Option<U256> {
        Some(self.confidential_compute_record.gas_price)
    }
}

impl SignableTransaction<Signature> for ConfidentialComputeRequest {
    fn set_chain_id(&mut self, chain_id: ChainId) {
        self.confidential_compute_record.chain_id = chain_id;
    }

    fn encode_for_signing(&self, out: &mut dyn alloy_rlp::BufMut) {
        out.put_u8(CCTypes::ConfidentialComputeRecord as u8);
        CcrHashingParams::from(self).encode(out);
    }

    fn payload_len_for_signature(&self) -> usize {
        941 //todo: calculate this with Encodable / Make checks
    }

    fn into_signed(self, signature: Signature) -> Signed<Self, Signature>
    where
        Self: Sized,
    {
        let hash = self.hash().into();
        Signed::new_unchecked(self, signature.with_parity_bool(), hash)
    }
}

use std::sync::Arc;

use alloy::{
    consensus::{
        self,
        TxEnvelope,
    },
    eips::eip2718::{
        Decodable2718,
        Encodable2718,
    },
    network::{
        BuilderResult,
        Network,
        NetworkSigner,
        TransactionBuilder,
        TransactionBuilderError,
        TxSigner,
    },
    providers::ProviderBuilder,
    rpc::types::eth::{
        Header as EthHeader,
        Transaction as TransactionResponse,
        TransactionReceipt,
    },
    signers::Result as SignerResult,
};
use async_trait::async_trait;

impl TransactionBuilder<SuaveNetwork> for ConfidentialComputeRequest {
    fn chain_id(&self) -> Option<ChainId> {
        Some(self.confidential_compute_record.chain_id)
    }

    fn set_chain_id(&mut self, chain_id: ChainId) {
        self.confidential_compute_record.chain_id = chain_id;
    }

    fn nonce(&self) -> Option<u64> {
        Some(self.confidential_compute_record.nonce)
    }

    fn set_nonce(&mut self, nonce: u64) {
        self.confidential_compute_record.nonce = nonce;
    }

    fn input(&self) -> Option<&Bytes> {
        Some(&self.confidential_compute_record.data)
    }

    fn set_input(&mut self, input: Bytes) {
        self.confidential_compute_record.data = input;
    }

    fn from(&self) -> Option<Address> {
        // todo: Check what is consensus on this
        None
    }

    fn set_from(&mut self, from: Address) {
        panic!("Cannot set from address for confidential compute request");
    }

    fn to(&self) -> Option<TxKind> {
        Some(TxKind::Call(self.confidential_compute_record.to))
    }

    fn set_to(&mut self, to: TxKind) {
        let new_address = match to {
            TxKind::Call(addr) => addr,
            TxKind::Create => Address::ZERO,
        };
        self.confidential_compute_record.to = new_address;
    }

    fn value(&self) -> Option<U256> {
        Some(self.confidential_compute_record.value)
    }

    fn set_value(&mut self, value: U256) {
        self.confidential_compute_record.value = value;
    }

    fn gas_price(&self) -> Option<U256> {
        Some(self.confidential_compute_record.gas_price)
    }

    fn set_gas_price(&mut self, gas_price: U256) {
        self.confidential_compute_record.gas_price = gas_price;
    }

    fn max_fee_per_gas(&self) -> Option<U256> {
        None
    }

    fn set_max_fee_per_gas(&mut self, max_fee_per_gas: U256) {
        panic!("Cannot set max fee per gas for confidential compute request");
    }

    fn max_priority_fee_per_gas(&self) -> Option<U256> {
        None
    }

    fn set_max_priority_fee_per_gas(&mut self, max_priority_fee_per_gas: U256) {
        panic!("Cannot set max priority fee per gas for confidential compute request");
    }

    fn max_fee_per_blob_gas(&self) -> Option<U256> {
        None
    }

    fn set_max_fee_per_blob_gas(&mut self, max_fee_per_blob_gas: U256) {
        panic!("Cannot set max fee per blob gas for confidential compute request");
    }

    fn gas_limit(&self) -> Option<U256> {
        Some(U256::from(self.confidential_compute_record.gas))
    }

    fn set_gas_limit(&mut self, gas_limit: U256) {
        let gas = gas_limit.try_into().expect("Overflowing gas param");
        self.confidential_compute_record.gas = gas;
    }

    fn get_blob_sidecar(&self) -> Option<&alloy::consensus::BlobTransactionSidecar> {
        None
    }

    fn set_blob_sidecar(&mut self, _blob_sidecar: alloy::consensus::BlobTransactionSidecar) {
        panic!("Cannot set blob sidecar for confidential compute request");
    }

    fn build_unsigned(self) -> BuilderResult<<SuaveNetwork as Network>::UnsignedTx> {
        // todo: have a different struct for built object
        Ok(self).map_err(|e| TransactionBuilderError::UnsupportedSignatureType)
    }

    async fn build<S: NetworkSigner<SuaveNetwork>>(
        self,
        signer: &S,
    ) -> BuilderResult<<SuaveNetwork as Network>::TxEnvelope> {
        // todo: need to add add v, r, s fields to ConfidentialComputeRecord and then rlp encode
        // map alloy::signers::Error to TransactionBuilderError error (TransactionBuilder::Signer =
        // alloy::signers::Error)
        signer
            .sign_transaction(self.build_unsigned()?)
            .await
            .map_err(|e| e.into())
    }
}

#[derive(Debug, Clone, Copy)]
pub struct SuaveNetwork;

impl Network for SuaveNetwork {
    type Header = consensus::Header;
    type HeaderResponse = EthHeader;
    type ReceiptEnvelope = TxEnvelope;
    // todo: speical type for this
    type ReceiptResponse = TransactionReceipt;
    type TransactionRequest = ConfidentialComputeRequest;
    type TransactionResponse = TransactionResponse;
    type TxEnvelope = ConfidentialComputeRequest;
    type UnsignedTx = ConfidentialComputeRequest;
}

impl Decodable2718 for ConfidentialComputeRequest {
    fn typed_decode(ty: u8, buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        println!("Decoding: {:?}", ty);
        todo!()
    }

    fn fallback_decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        println!("Decoding(fallback): {:?}", buf);
        todo!()
    }
}

impl Encodable2718 for ConfidentialComputeRequest {
    fn type_flag(&self) -> Option<u8> {
        Some(CCTypes::ConfidentialComputeRequest as u8)
    }

    fn encode_2718_len(&self) -> usize {
        941 //todo: calculate this with Encodable / Make checks
    }

    fn encode_2718(&self, out: &mut dyn alloy_rlp::BufMut) {
        out.put_u8(CCTypes::ConfidentialComputeRequest as u8);
        CcRequestRlp::from(self).encode(out);
    }
}

#[derive(Clone)]
pub struct SuaveSigner(Arc<dyn TxSigner<Signature> + Send + Sync>);

impl std::fmt::Debug for SuaveSigner {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("SuaveSigner").finish()
    }
}

impl<S> From<S> for SuaveSigner
where
    S: TxSigner<Signature> + Send + Sync + 'static,
{
    fn from(signer: S) -> Self {
        Self::new(signer)
    }
}

impl SuaveSigner {
    /// Create a new Ethereum signer.
    pub fn new<S>(signer: S) -> Self
    where
        S: TxSigner<Signature> + Send + Sync + 'static,
    {
        Self(Arc::new(signer))
    }

    async fn sign_transaction(
        &self,
        tx: &mut ConfidentialComputeRequest,
    ) -> SignerResult<ConfidentialComputeRequest> {
        self.0.sign_transaction(tx).await.map(|sig| {
            let v = sig.v().recid().to_byte();
            let r = sig.r();
            let s = sig.s();
            tx.confidential_compute_record.set_sig(v, r, s);

            tx.clone()
        })
    }
}

#[cfg_attr(target_arch = "wasm32", async_trait(?Send))]
#[cfg_attr(not(target_arch = "wasm32"), async_trait)]
impl<N> NetworkSigner<N> for SuaveSigner
where
    N: Network<UnsignedTx = ConfidentialComputeRequest, TxEnvelope = ConfidentialComputeRequest>,
{
    async fn sign_transaction(
        &self,
        tx: ConfidentialComputeRequest,
    ) -> SignerResult<ConfidentialComputeRequest> {
        let mut tx = tx;
        self.sign_transaction(&mut tx).await
    }
}

#[cfg(test)]
mod tests {
    use core::time;
    use std::{
        str::FromStr,
        thread,
    };

    use alloy::{
        network::{
            TransactionBuilder,
            TxSigner,
        },
        primitives::B256,
        providers::{
            Provider,
            ProviderBuilder,
        },
        rpc::types::eth::TransactionRequest,
        signers::wallet::LocalWallet,
    };

    use super::*;

    #[test]
    fn test_ccr_rlp_encode() {
        let chain_id = 0x067932;
        let execution_node =
            Address::from_str("0x7d83e42b214b75bf1f3e57adc3415da573d97bff").unwrap();
        let to_add = Address::from_str("0x780675d71ebe3d3ef05fae379063071147dd3aee").unwrap();
        let input = Bytes::from_str("0x236eb5a70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000780675d71ebe3d3ef05fae379063071147dd3aee0000000000000000000000000000000000000000000000000000000000000000").unwrap();
        let tx = TransactionRequest::default()
            .to(Some(to_add))
            .gas_limit(U256::from(0x0f4240))
            .with_gas_price(U256::from(0x3b9aca00))
            .with_chain_id(chain_id)
            .with_nonce(0x22)
            .with_input(input);

        let mut cc_record = ConfidentialComputeRecord::from_tx_request(tx, execution_node);

        let v = 0;
        let r =
            U256::from_str("0x1567c31c4bebcd1061edbaf22dd73fd40ff30f9a3ba4525037f23b2dc61e3473")
                .unwrap();
        let s =
            U256::from_str("0x2dce69262794a499d525c5d58edde33e06a5847b4d321d396b743700a2fd71a8")
                .unwrap();
        cc_record.set_sig(v, r, s);

        let confidential_inputs = Bytes::from_str("0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001ea7b22747873223a5b7b2274797065223a22307830222c226e6f6e6365223a22307830222c22746f223a22307863613135656439393030366236623130363038653236313631373361313561343766383933613661222c22676173223a22307835323038222c226761735072696365223a22307864222c226d61785072696f72697479466565506572476173223a6e756c6c2c226d6178466565506572476173223a6e756c6c2c2276616c7565223a223078336538222c22696e707574223a223078222c2276223a2230786366323838222c2272223a22307863313764616536383866396262393632376563636439626636393133626661346539643232383139353134626539323066343435653263666165343366323965222c2273223a22307835633337646235386263376161336465306535656638613432353261366632653464313462613639666338323631636333623630633962643236613634626265222c2268617368223a22307862643263653662653964333461366132393934373239346662656137643461343834646663363565643963383931396533626539366131353634363630656265227d5d2c2270657263656e74223a31302c224d617463684964223a5b302c302c302c302c302c302c302c302c302c302c302c302c302c302c302c305d7d00000000000000000000000000000000000000000000").unwrap();
        let cc_request = ConfidentialComputeRequest::new(cc_record, confidential_inputs);
        let rlp_encoded = cc_request.rlp_encode().unwrap();

        let expected_rlp_encoded = Bytes::from_str("0x43f903a9f9016322843b9aca00830f424094780675d71ebe3d3ef05fae379063071147dd3aee80b8c4236eb5a70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000780675d71ebe3d3ef05fae379063071147dd3aee0000000000000000000000000000000000000000000000000000000000000000947d83e42b214b75bf1f3e57adc3415da573d97bffa089ee438ca379ac86b0478517d43a6a9e078cf51543acac0facd68aff313e2ff18306793280a01567c31c4bebcd1061edbaf22dd73fd40ff30f9a3ba4525037f23b2dc61e3473a02dce69262794a499d525c5d58edde33e06a5847b4d321d396b743700a2fd71a8b90240000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001ea7b22747873223a5b7b2274797065223a22307830222c226e6f6e6365223a22307830222c22746f223a22307863613135656439393030366236623130363038653236313631373361313561343766383933613661222c22676173223a22307835323038222c226761735072696365223a22307864222c226d61785072696f72697479466565506572476173223a6e756c6c2c226d6178466565506572476173223a6e756c6c2c2276616c7565223a223078336538222c22696e707574223a223078222c2276223a2230786366323838222c2272223a22307863313764616536383866396262393632376563636439626636393133626661346539643232383139353134626539323066343435653263666165343366323965222c2273223a22307835633337646235386263376161336465306535656638613432353261366632653464313462613639666338323631636333623630633962643236613634626265222c2268617368223a22307862643263653662653964333461366132393934373239346662656137643461343834646663363565643963383931396533626539366131353634363630656265227d5d2c2270657263656e74223a31302c224d617463684964223a5b302c302c302c302c302c302c302c302c302c302c302c302c302c302c302c305d7d00000000000000000000000000000000000000000000").unwrap();

        assert_eq!(rlp_encoded, expected_rlp_encoded);
    }

    #[test]
    fn test_ccr_sign_hash() {
        let execution_node =
            Address::from_str("0x7d83e42b214b75bf1f3e57adc3415da573d97bff").unwrap();
        let to_add = Address::from_str("0x772092ff73c43883a547bea1e1e007ec0d33478e").unwrap();
        let input = Bytes::from_str("0x236eb5a70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000772092ff73c43883a547bea1e1e007ec0d33478e0000000000000000000000000000000000000000000000000000000000000000").unwrap();
        let cinputs = Bytes::from_str("0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001ea7b22747873223a5b7b2274797065223a22307830222c226e6f6e6365223a22307830222c22746f223a22307838626265386333346637396433353534666631626236643932313733613237666661356237313233222c22676173223a22307835323038222c226761735072696365223a22307864222c226d61785072696f72697479466565506572476173223a6e756c6c2c226d6178466565506572476173223a6e756c6c2c2276616c7565223a223078336538222c22696e707574223a223078222c2276223a2230786366323837222c2272223a22307862396433643236643135633630376237653537353235333761336163326432363330643161653036386163353138616539393862613439313236323134383135222c2273223a22307835636534666439613565376533373138656630613731386533633462333135306538373036376533373361333439323538643962333330353930396332303565222c2268617368223a22307863633934626637386463366631373963663331376638643839353438393364393730303366333266353332623530623865333861626631333939353364643664227d5d2c2270657263656e74223a31302c224d617463684964223a5b302c302c302c302c302c302c302c302c302c302c302c302c302c302c302c305d7d00000000000000000000000000000000000000000000").unwrap();
        let cinputs_hash = primitives::keccak256(&cinputs);

        let hash_params = CcrHashingParams {
            execution_node,
            confidential_inputs_hash: cinputs_hash,
            nonce: 0x18,
            gas_price: U256::from_str("0x3b9aca00").unwrap(),
            gas: 0x0f4240,
            to: to_add,
            value: U256::ZERO,
            data: input,
        };
        let encoded = encode_with_prefix(CCTypes::ConfidentialComputeRecord as u8, hash_params);
        let hash = primitives::keccak256(&encoded);

        let expected_hash = FixedBytes::from_str(
            "0x72ffab40c5116931200ca87052360787559871297b3615a8c2ff28be738ac59f",
        )
        .unwrap();
        assert_eq!(hash, expected_hash);
    }

    #[tokio::test]
    async fn test_ccr_sign() {
        // Create a cc request
        let cinputs = Bytes::from_str("0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001ea7b22747873223a5b7b2274797065223a22307830222c226e6f6e6365223a22307830222c22746f223a22307863613135656439393030366236623130363038653236313631373361313561343766383933613661222c22676173223a22307835323038222c226761735072696365223a22307864222c226d61785072696f72697479466565506572476173223a6e756c6c2c226d6178466565506572476173223a6e756c6c2c2276616c7565223a223078336538222c22696e707574223a223078222c2276223a2230786366323838222c2272223a22307863313764616536383866396262393632376563636439626636393133626661346539643232383139353134626539323066343435653263666165343366323965222c2273223a22307835633337646235386263376161336465306535656638613432353261366632653464313462613639666338323631636333623630633962643236613634626265222c2268617368223a22307862643263653662653964333461366132393934373239346662656137643461343834646663363565643963383931396533626539366131353634363630656265227d5d2c2270657263656e74223a31302c224d617463684964223a5b302c302c302c302c302c302c302c302c302c302c302c302c302c302c302c305d7d00000000000000000000000000000000000000000000").unwrap();
        let execution_node =
            Address::from_str("0x7d83e42b214b75bf1f3e57adc3415da573d97bff").unwrap();
        let nonce = 0x22;
        let to_add = Address::from_str("0x780675d71ebe3d3ef05fae379063071147dd3aee").unwrap();
        let gas = 0x0f4240;
        let gas_price = U256::from_str("0x3b9aca00").unwrap();
        let input = Bytes::from_str("0x236eb5a70000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000780675d71ebe3d3ef05fae379063071147dd3aee0000000000000000000000000000000000000000000000000000000000000000").unwrap();
        let chain_id = 0x067932;
        let tx = TransactionRequest::default()
            .to(Some(to_add))
            .gas_limit(U256::from(gas))
            .with_gas_price(gas_price)
            .with_chain_id(chain_id)
            .with_nonce(nonce)
            .with_input(input);
        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, execution_node);
        let mut cc_request = ConfidentialComputeRequest::new(cc_record, cinputs);

        // Sign
        let pk = "0x1111111111111111111111111111111111111111111111111111111111111111";
        let wallet: LocalWallet = pk.parse().unwrap();
        let sig = wallet.sign_transaction(&mut cc_request).await.unwrap();

        // Check signature
        assert_eq!(sig.v().recid().to_byte(), 0_u8);
        assert_eq!(
            sig.r(),
            U256::from_str("0x1567c31c4bebcd1061edbaf22dd73fd40ff30f9a3ba4525037f23b2dc61e3473")
                .unwrap()
        );
        assert_eq!(
            sig.s(),
            U256::from_str("0x2dce69262794a499d525c5d58edde33e06a5847b4d321d396b743700a2fd71a8")
                .unwrap()
        );
    }

    // todo: do a proper test
    #[tokio::test]
    async fn test_send_tx_rigil() {
        let rpc_url = url::Url::parse("http://127.0.0.1:8545").unwrap();
        let provider = ProviderBuilder::new()
            .on_reqwest_http(rpc_url.clone())
            .unwrap();
        let wallet_address =
            Address::from_str("0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f").unwrap();
        let tx_count: u64 = provider
            .get_transaction_count(wallet_address, None)
            .await
            .unwrap()
            .to();
        let mut gas_price = provider.get_gas_price().await.unwrap();
        gas_price = gas_price.checked_mul(U256::from(10).into()).unwrap();
        // Create a cc request
        let cinputs = Bytes::from_str("0x0022").unwrap();
        let execution_node =
            Address::from_str("0xb5feafbdd752ad52afb7e1bd2e40432a485bbb7f").unwrap();
        let nonce = tx_count;
        println!("nonce: {}", nonce);
        let to_add = Address::from_str("0xd594760B2A36467ec7F0267382564772D7b0b73c").unwrap(); // auction suapp
        let gas = 0x0f4240;
        let input = Bytes::from_str("0xf335e395").unwrap();
        let chain_id = 0x1008c45;
        let tx = TransactionRequest::default()
            .to(Some(to_add))
            .gas_limit(U256::from(gas))
            .with_gas_price(gas_price)
            .with_chain_id(chain_id)
            .with_nonce(nonce)
            .with_input(input);
        println!("Tx: {:?}", tx);
        let cc_record = ConfidentialComputeRecord::from_tx_request(tx, execution_node);
        let cc_request = ConfidentialComputeRequest::new(cc_record, cinputs);

        let pk = "0x6c45335a22461ccdb978b78ab61b238bad2fae4544fb55c14eb096c875ccfc52";
        let wallet: LocalWallet = pk.parse().unwrap();

        let signer = SuaveSigner::from(wallet.clone());
        // let provider =
        //     ProviderBuilder::new().signer(signer).on_reqwest_http(rpc_url)?;
        let provider = ProviderBuilder::<_, SuaveNetwork>::default()
            .signer(signer)
            .on_reqwest_http(rpc_url)
            .unwrap();

        let result = provider.send_transaction(cc_request).await.unwrap();
        let tx_hash = B256::from_slice(&result.tx_hash().to_vec());
        println!("Tx Hash: {:?}", tx_hash);
        let ten_millis = time::Duration::from_millis(10);
        thread::sleep(ten_millis);

        let tx_response = provider
            .get_transaction_by_hash(tx_hash)
            .await
            .expect("failed to read tx response");
        println!("{:#?}", tx_response);
        // provider.send_transaction(cc_request).await.unwrap();
    }
}
