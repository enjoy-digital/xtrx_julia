using CEnum

struct LMS7002M_regs_struct
    reg_0x0020_lrst_tx_b::Cint
    reg_0x0020_mrst_tx_b::Cint
    reg_0x0020_lrst_tx_a::Cint
    reg_0x0020_mrst_tx_a::Cint
    reg_0x0020_lrst_rx_b::Cint
    reg_0x0020_mrst_rx_b::Cint
    reg_0x0020_lrst_rx_a::Cint
    reg_0x0020_mrst_rx_a::Cint
    reg_0x0020_srst_rxfifo::Cint
    reg_0x0020_srst_txfifo::Cint
    reg_0x0020_rxen_b::Cint
    reg_0x0020_rxen_a::Cint
    reg_0x0020_txen_b::Cint
    reg_0x0020_txen_a::Cint
    reg_0x0020_mac::Cint
    reg_0x0021_tx_clk_pe::Cint
    reg_0x0021_rx_clk_pe::Cint
    reg_0x0021_sda_pe::Cint
    reg_0x0021_sda_ds::Cint
    reg_0x0021_scl_pe::Cint
    reg_0x0021_scl_ds::Cint
    reg_0x0021_sdio_ds::Cint
    reg_0x0021_sdio_pe::Cint
    reg_0x0021_sdo_pe::Cint
    reg_0x0021_sclk_pe::Cint
    reg_0x0021_sen_pe::Cint
    reg_0x0021_spimode::Cint
    reg_0x0022_diq2_ds::Cint
    reg_0x0022_diq2_pe::Cint
    reg_0x0022_iq_sel_en_2_pe::Cint
    reg_0x0022_txnrx2_pe::Cint
    reg_0x0022_fclk2_pe::Cint
    reg_0x0022_mclk2_pe::Cint
    reg_0x0022_diq1_ds::Cint
    reg_0x0022_diq1_pe::Cint
    reg_0x0022_iq_sel_en_1_pe::Cint
    reg_0x0022_txnrx1_pe::Cint
    reg_0x0022_fclk1_pe::Cint
    reg_0x0022_mclk1_pe::Cint
    reg_0x0023_diqdirctr2::Cint
    reg_0x0023_diqdir2::Cint
    reg_0x0023_diqdirctr1::Cint
    reg_0x0023_diqdir1::Cint
    reg_0x0023_enabledirctr2::Cint
    reg_0x0023_enabledir2::Cint
    reg_0x0023_enabledirctr1::Cint
    reg_0x0023_enabledir1::Cint
    reg_0x0023_mod_en::Cint
    reg_0x0023_lml2_fidm::Cint
    reg_0x0023_lml2_rxntxiq::Cint
    reg_0x0023_lml2_mode::Cint
    reg_0x0023_lml1_fidm::Cint
    reg_0x0023_lml1_rxntxiq::Cint
    reg_0x0023_lml1_mode::Cint
    reg_0x0024_lml1_s3s::Cint
    reg_0x0024_lml1_s2s::Cint
    reg_0x0024_lml1_s1s::Cint
    reg_0x0024_lml1_s0s::Cint
    reg_0x0024_lml1_bqp::Cint
    reg_0x0024_lml1_bip::Cint
    reg_0x0024_lml1_aqp::Cint
    reg_0x0024_lml1_aip::Cint
    reg_0x0025_value::Cint
    reg_0x0026_value::Cint
    reg_0x0027_lml2_s3s::Cint
    reg_0x0027_lml2_s2s::Cint
    reg_0x0027_lml2_s1s::Cint
    reg_0x0027_lml2_s0s::Cint
    reg_0x0027_lml2_bqp::Cint
    reg_0x0027_lml2_bip::Cint
    reg_0x0027_lml2_aqp::Cint
    reg_0x0027_lml2_aip::Cint
    reg_0x0028_value::Cint
    reg_0x0029_value::Cint
    reg_0x002a_fclk2_dly::Cint
    reg_0x002a_fclk1_dly::Cint
    reg_0x002a_rx_mux::Cint
    reg_0x002a_tx_mux::Cint
    reg_0x002a_txrdclk_mux::Cint
    reg_0x002a_txwrclk_mux::Cint
    reg_0x002a_rxrdclk_mux::Cint
    reg_0x002a_rxwrclk_mux::Cint
    reg_0x002b_fclk2_inv::Cint
    reg_0x002b_fclk1_inv::Cint
    reg_0x002b_mclk2_dly::Cint
    reg_0x002b_mclk1_dly::Cint
    reg_0x002b_mclk2_inv::Cint
    reg_0x002b_mclk1_inv::Cint
    reg_0x002b_mclk2src::Cint
    reg_0x002b_mclk1src::Cint
    reg_0x002b_txdiven::Cint
    reg_0x002b_rxdiven::Cint
    reg_0x002c_txtspclk_div::Cint
    reg_0x002c_rxtspclk_div::Cint
    reg_0x002e_mimo_siso::Cint
    reg_0x002f_ver::Cint
    reg_0x002f_rev::Cint
    reg_0x002f_mask::Cint
    reg_0x0081_en_dir_ldo::Cint
    reg_0x0081_en_dir_cgen::Cint
    reg_0x0081_en_dir_xbuf::Cint
    reg_0x0081_en_dir_afe::Cint
    reg_0x0082_isel_dac_afe::Cint
    reg_0x0082_mode_interleave_afe::Cint
    reg_0x0082_mux_afe_1::Cint
    reg_0x0082_mux_afe_2::Cint
    reg_0x0082_pd_afe::Cint
    reg_0x0082_pd_rx_afe1::Cint
    reg_0x0082_pd_rx_afe2::Cint
    reg_0x0082_pd_tx_afe1::Cint
    reg_0x0082_pd_tx_afe2::Cint
    reg_0x0082_en_g_afe::Cint
    reg_0x0084_mux_bias_out::Cint
    reg_0x0084_rp_calib_bias::Cint
    reg_0x0084_pd_frp_bias::Cint
    reg_0x0084_pd_f_bias::Cint
    reg_0x0084_pd_ptrp_bias::Cint
    reg_0x0084_pd_pt_bias::Cint
    reg_0x0084_pd_bias_master::Cint
    reg_0x0085_slfb_xbuf_rx::Cint
    reg_0x0085_slfb_xbuf_tx::Cint
    reg_0x0085_byp_xbuf_rx::Cint
    reg_0x0085_byp_xbuf_tx::Cint
    reg_0x0085_en_out2_xbuf_tx::Cint
    reg_0x0085_en_tbufin_xbuf_rx::Cint
    reg_0x0085_pd_xbuf_rx::Cint
    reg_0x0085_pd_xbuf_tx::Cint
    reg_0x0085_en_g_xbuf::Cint
    reg_0x0086_spdup_vco_cgen::Cint
    reg_0x0086_reset_n_cgen::Cint
    reg_0x0086_en_adcclkh_clkgn::Cint
    reg_0x0086_en_coarse_cklgen::Cint
    reg_0x0086_en_intonly_sdm_cgen::Cint
    reg_0x0086_en_sdm_clk_cgen::Cint
    reg_0x0086_pd_cp_cgen::Cint
    reg_0x0086_pd_fdiv_fb_cgen::Cint
    reg_0x0086_pd_fdiv_o_cgen::Cint
    reg_0x0086_pd_sdm_cgen::Cint
    reg_0x0086_pd_vco_cgen::Cint
    reg_0x0086_pd_vco_comp_cgen::Cint
    reg_0x0086_en_g_cgen::Cint
    reg_0x0087_frac_sdm_cgen::Cint
    reg_0x0088_int_sdm_cgen::Cint
    reg_0x0088_frac_sdm_cgen::Cint
    reg_0x0089_rev_sdmclk_cgen::Cint
    reg_0x0089_sel_sdmclk_cgen::Cint
    reg_0x0089_sx_dither_en_cgen::Cint
    reg_0x0089_clkh_ov_clkl_cgen::Cint
    reg_0x0089_div_outch_cgen::Cint
    reg_0x0089_tst_cgen::Cint
    reg_0x008a_rev_clkdac_cgen::Cint
    reg_0x008a_rev_clkadc_cgen::Cint
    reg_0x008a_revph_pfd_cgen::Cint
    reg_0x008a_ioffset_cp_cgen::Cint
    reg_0x008a_ipulse_cp_cgen::Cint
    reg_0x008b_ict_vco_cgen::Cint
    reg_0x008b_csw_vco_cgen::Cint
    reg_0x008b_coarse_start_cgen::Cint
    reg_0x008c_coarse_stepdone_cgen::Cint
    reg_0x008c_coarsepll_compo_cgen::Cint
    reg_0x008c_vco_cmpho_cgen::Cint
    reg_0x008c_vco_cmplo_cgen::Cint
    reg_0x008c_cp2_cgen::Cint
    reg_0x008c_cp3_cgen::Cint
    reg_0x008c_cz_cgen::Cint
    reg_0x008d_resrv_cgn::Cint
    reg_0x0092_en_ldo_dig::Cint
    reg_0x0092_en_ldo_diggn::Cint
    reg_0x0092_en_ldo_digsxr::Cint
    reg_0x0092_en_ldo_digsxt::Cint
    reg_0x0092_en_ldo_divgn::Cint
    reg_0x0092_en_ldo_divsxr::Cint
    reg_0x0092_en_ldo_divsxt::Cint
    reg_0x0092_en_ldo_lna12::Cint
    reg_0x0092_en_ldo_lna14::Cint
    reg_0x0092_en_ldo_mxrfe::Cint
    reg_0x0092_en_ldo_rbb::Cint
    reg_0x0092_en_ldo_rxbuf::Cint
    reg_0x0092_en_ldo_tbb::Cint
    reg_0x0092_en_ldo_tia12::Cint
    reg_0x0092_en_ldo_tia14::Cint
    reg_0x0092_en_g_ldo::Cint
    reg_0x0093_en_loadimp_ldo_tlob::Cint
    reg_0x0093_en_loadimp_ldo_tpad::Cint
    reg_0x0093_en_loadimp_ldo_txbuf::Cint
    reg_0x0093_en_loadimp_ldo_vcogn::Cint
    reg_0x0093_en_loadimp_ldo_vcosxr::Cint
    reg_0x0093_en_loadimp_ldo_vcosxt::Cint
    reg_0x0093_en_ldo_afe::Cint
    reg_0x0093_en_ldo_cpgn::Cint
    reg_0x0093_en_ldo_cpsxr::Cint
    reg_0x0093_en_ldo_tlob::Cint
    reg_0x0093_en_ldo_tpad::Cint
    reg_0x0093_en_ldo_txbuf::Cint
    reg_0x0093_en_ldo_vcogn::Cint
    reg_0x0093_en_ldo_vcosxr::Cint
    reg_0x0093_en_ldo_vcosxt::Cint
    reg_0x0093_en_ldo_cpsxt::Cint
    reg_0x0094_en_loadimp_ldo_cpsxt::Cint
    reg_0x0094_en_loadimp_ldo_dig::Cint
    reg_0x0094_en_loadimp_ldo_diggn::Cint
    reg_0x0094_en_loadimp_ldo_digsxr::Cint
    reg_0x0094_en_loadimp_ldo_digsxt::Cint
    reg_0x0094_en_loadimp_ldo_divgn::Cint
    reg_0x0094_en_loadimp_ldo_divsxr::Cint
    reg_0x0094_en_loadimp_ldo_divsxt::Cint
    reg_0x0094_en_loadimp_ldo_lna12::Cint
    reg_0x0094_en_loadimp_ldo_lna14::Cint
    reg_0x0094_en_loadimp_ldo_mxrfe::Cint
    reg_0x0094_en_loadimp_ldo_rbb::Cint
    reg_0x0094_en_loadimp_ldo_rxbuf::Cint
    reg_0x0094_en_loadimp_ldo_tbb::Cint
    reg_0x0094_en_loadimp_ldo_tia12::Cint
    reg_0x0094_en_loadimp_ldo_tia14::Cint
    reg_0x0095_byp_ldo_tbb::Cint
    reg_0x0095_byp_ldo_tia12::Cint
    reg_0x0095_byp_ldo_tia14::Cint
    reg_0x0095_byp_ldo_tlob::Cint
    reg_0x0095_byp_ldo_tpad::Cint
    reg_0x0095_byp_ldo_txbuf::Cint
    reg_0x0095_byp_ldo_vcogn::Cint
    reg_0x0095_byp_ldo_vcosxr::Cint
    reg_0x0095_byp_ldo_vcosxt::Cint
    reg_0x0095_en_loadimp_ldo_afe::Cint
    reg_0x0095_en_loadimp_ldo_cpgn::Cint
    reg_0x0095_en_loadimp_ldo_cpsxr::Cint
    reg_0x0096_byp_ldo_afe::Cint
    reg_0x0096_byp_ldo_cpgn::Cint
    reg_0x0096_byp_ldo_cpsxr::Cint
    reg_0x0096_byp_ldo_cpsxt::Cint
    reg_0x0096_byp_ldo_dig::Cint
    reg_0x0096_byp_ldo_diggn::Cint
    reg_0x0096_byp_ldo_digsxr::Cint
    reg_0x0096_byp_ldo_digsxt::Cint
    reg_0x0096_byp_ldo_divgn::Cint
    reg_0x0096_byp_ldo_divsxr::Cint
    reg_0x0096_byp_ldo_divsxt::Cint
    reg_0x0096_byp_ldo_lna12::Cint
    reg_0x0096_byp_ldo_lna14::Cint
    reg_0x0096_byp_ldo_mxrfe::Cint
    reg_0x0096_byp_ldo_rbb::Cint
    reg_0x0096_byp_ldo_rxbuf::Cint
    reg_0x0097_spdup_ldo_divsxr::Cint
    reg_0x0097_spdup_ldo_divsxt::Cint
    reg_0x0097_spdup_ldo_lna12::Cint
    reg_0x0097_spdup_ldo_lna14::Cint
    reg_0x0097_spdup_ldo_mxrfe::Cint
    reg_0x0097_spdup_ldo_rbb::Cint
    reg_0x0097_spdup_ldo_rxbuf::Cint
    reg_0x0097_spdup_ldo_tbb::Cint
    reg_0x0097_spdup_ldo_tia12::Cint
    reg_0x0097_spdup_ldo_tia14::Cint
    reg_0x0097_spdup_ldo_tlob::Cint
    reg_0x0097_spdup_ldo_tpad::Cint
    reg_0x0097_spdup_ldo_txbuf::Cint
    reg_0x0097_spdup_ldo_vcogn::Cint
    reg_0x0097_spdup_ldo_vcosxr::Cint
    reg_0x0097_spdup_ldo_vcosxt::Cint
    reg_0x0098_spdup_ldo_afe::Cint
    reg_0x0098_spdup_ldo_cpgn::Cint
    reg_0x0098_spdup_ldo_cpsxr::Cint
    reg_0x0098_spdup_ldo_cpsxt::Cint
    reg_0x0098_spdup_ldo_dig::Cint
    reg_0x0098_spdup_ldo_diggn::Cint
    reg_0x0098_spdup_ldo_digsxr::Cint
    reg_0x0098_spdup_ldo_digsxt::Cint
    reg_0x0098_spdup_ldo_divgn::Cint
    reg_0x0099_rdiv_vcosxr::Cint
    reg_0x0099_rdiv_vcosxt::Cint
    reg_0x009a_rdiv_txbuf::Cint
    reg_0x009a_rdiv_vcogn::Cint
    reg_0x009b_rdiv_tlob::Cint
    reg_0x009b_rdiv_tpad::Cint
    reg_0x009c_rdiv_tia12::Cint
    reg_0x009c_rdiv_tia14::Cint
    reg_0x009d_rdiv_rxbuf::Cint
    reg_0x009d_rdiv_tbb::Cint
    reg_0x009e_rdiv_mxrfe::Cint
    reg_0x009e_rdiv_rbb::Cint
    reg_0x009f_rdiv_lna12::Cint
    reg_0x009f_rdiv_lna14::Cint
    reg_0x00a0_rdiv_divsxr::Cint
    reg_0x00a0_rdiv_divsxt::Cint
    reg_0x00a1_rdiv_digsxt::Cint
    reg_0x00a1_rdiv_divgn::Cint
    reg_0x00a2_rdiv_diggn::Cint
    reg_0x00a2_rdiv_digsxr::Cint
    reg_0x00a3_rdiv_cpsxt::Cint
    reg_0x00a3_rdiv_dig::Cint
    reg_0x00a4_rdiv_cpgn::Cint
    reg_0x00a4_rdiv_cpsxr::Cint
    reg_0x00a5_rdiv_spibuf::Cint
    reg_0x00a5_rdiv_afe::Cint
    reg_0x00a6_spdup_ldo_spibuf::Cint
    reg_0x00a6_spdup_ldo_digip2::Cint
    reg_0x00a6_spdup_ldo_digip1::Cint
    reg_0x00a6_byp_ldo_spibuf::Cint
    reg_0x00a6_byp_ldo_digip2::Cint
    reg_0x00a6_byp_ldo_digip1::Cint
    reg_0x00a6_en_loadimp_ldo_spibuf::Cint
    reg_0x00a6_en_loadimp_ldo_digip2::Cint
    reg_0x00a6_en_loadimp_ldo_digip1::Cint
    reg_0x00a6_pd_ldo_spibuf::Cint
    reg_0x00a6_pd_ldo_digip2::Cint
    reg_0x00a6_pd_ldo_digip1::Cint
    reg_0x00a6_en_g_ldop::Cint
    reg_0x00a7_rdiv_digip2::Cint
    reg_0x00a7_rdiv_digip1::Cint
    reg_0x00a8_value::Cint
    reg_0x00aa_value::Cint
    reg_0x00ab_value::Cint
    reg_0x00ad_value::Cint
    reg_0x00ae_value::Cint
    reg_0x0100_en_lowbwlomx_tmx_trf::Cint
    reg_0x0100_en_nexttx_trf::Cint
    reg_0x0100_en_amphf_pdet_trf::Cint
    reg_0x0100_loadr_pdet_trf::Cint
    reg_0x0100_pd_pdet_trf::Cint
    reg_0x0100_pd_tlobuf_trf::Cint
    reg_0x0100_pd_txpad_trf::Cint
    reg_0x0100_en_g_trf::Cint
    reg_0x0101_f_txpad_trf::Cint
    reg_0x0101_l_loopb_txpad_trf::Cint
    reg_0x0101_loss_lin_txpad_trf::Cint
    reg_0x0101_loss_main_txpad_trf::Cint
    reg_0x0101_en_loopb_txpad_trf::Cint
    reg_0x0102_gcas_gndref_txpad_trf::Cint
    reg_0x0102_ict_lin_txpad_trf::Cint
    reg_0x0102_ict_main_txpad_trf::Cint
    reg_0x0102_vgcas_txpad_trf::Cint
    reg_0x0103_sel_band1_trf::Cint
    reg_0x0103_sel_band2_trf::Cint
    reg_0x0103_lobiasn_txm_trf::Cint
    reg_0x0103_lobiasp_txx_trf::Cint
    reg_0x0104_cdc_i_trf::Cint
    reg_0x0104_cdc_q_trf::Cint
    reg_0x0105_statpulse_tbb::Cint
    reg_0x0105_loopb_tbb::Cint
    reg_0x0105_pd_lpfh_tbb::Cint
    reg_0x0105_pd_lpfiamp_tbb::Cint
    reg_0x0105_pd_lpflad_tbb::Cint
    reg_0x0105_pd_lpfs5_tbb::Cint
    reg_0x0105_en_g_tbb::Cint
    reg_0x0106_ict_lpfs5_f_tbb::Cint
    reg_0x0106_ict_lpfs5_pt_tbb::Cint
    reg_0x0106_ict_lpf_h_pt_tbb::Cint
    reg_0x0107_ict_lpfh_f_tbb::Cint
    reg_0x0107_ict_lpflad_f_tbb::Cint
    reg_0x0107_ict_lpflad_pt_tbb::Cint
    reg_0x0108_cg_iamp_tbb::Cint
    reg_0x0108_ict_iamp_frp_tbb::Cint
    reg_0x0108_ict_iamp_gg_frp_tbb::Cint
    reg_0x0109_rcal_lpfh_tbb::Cint
    reg_0x0109_rcal_lpflad_tbb::Cint
    reg_0x010a_tstin_tbb::Cint
    reg_0x010a_bypladder_tbb::Cint
    reg_0x010a_ccal_lpflad_tbb::Cint
    reg_0x010a_rcal_lpfs5_tbb::Cint
    reg_0x010b_value::Cint
    reg_0x010c_cdc_i_rfe::Cint
    reg_0x010c_cdc_q_rfe::Cint
    reg_0x010c_pd_lna_rfe::Cint
    reg_0x010c_pd_rloopb_1_rfe::Cint
    reg_0x010c_pd_rloopb_2_rfe::Cint
    reg_0x010c_pd_mxlobuf_rfe::Cint
    reg_0x010c_pd_qgen_rfe::Cint
    reg_0x010c_pd_rssi_rfe::Cint
    reg_0x010c_pd_tia_rfe::Cint
    reg_0x010c_en_g_rfe::Cint
    reg_0x010d_sel_path_rfe::Cint
    reg_0x010d_en_dcoff_rxfe_rfe::Cint
    reg_0x010d_en_inshsw_lb1_rfe::Cint
    reg_0x010d_en_inshsw_lb2_rfe::Cint
    reg_0x010d_en_inshsw_l_rfe::Cint
    reg_0x010d_en_inshsw_w_rfe::Cint
    reg_0x010d_en_nextrx_rfe::Cint
    reg_0x010e_dcoffi_rfe::Cint
    reg_0x010e_dcoffq_rfe::Cint
    reg_0x010f_ict_loopb_rfe::Cint
    reg_0x010f_ict_tiamain_rfe::Cint
    reg_0x010f_ict_tiaout_rfe::Cint
    reg_0x0110_ict_lnacmo_rfe::Cint
    reg_0x0110_ict_lna_rfe::Cint
    reg_0x0110_ict_lodc_rfe::Cint
    reg_0x0111_cap_rxmxo_rfe::Cint
    reg_0x0111_cgsin_lna_rfe::Cint
    reg_0x0112_ccomp_tia_rfe::Cint
    reg_0x0112_cfb_tia_rfe::Cint
    reg_0x0113_g_lna_rfe::Cint
    reg_0x0113_g_rxloopb_rfe::Cint
    reg_0x0113_g_tia_rfe::Cint
    reg_0x0114_rcomp_tia_rfe::Cint
    reg_0x0114_rfb_tia_rfe::Cint
    reg_0x0115_en_lb_lpfh_rbb::Cint
    reg_0x0115_en_lb_lpfl_rbb::Cint
    reg_0x0115_pd_lpfh_rbb::Cint
    reg_0x0115_pd_lpfl_rbb::Cint
    reg_0x0115_pd_pga_rbb::Cint
    reg_0x0115_en_g_rbb::Cint
    reg_0x0116_r_ctl_lpf_rbb::Cint
    reg_0x0116_rcc_ctl_lpfh_rbb::Cint
    reg_0x0116_c_ctl_lpfh_rbb::Cint
    reg_0x0117_rcc_ctl_lpfl_rbb::Cint
    reg_0x0117_c_ctl_lpfl_rbb::Cint
    reg_0x0118_input_ctl_pga_rbb::Cint
    reg_0x0118_ict_lpf_in_rbb::Cint
    reg_0x0118_ict_lpf_out_rbb::Cint
    reg_0x0119_osw_pga_rbb::Cint
    reg_0x0119_ict_pga_out_rbb::Cint
    reg_0x0119_ict_pga_in_rbb::Cint
    reg_0x0119_g_pga_rbb::Cint
    reg_0x011a_rcc_ctl_pga_rbb::Cint
    reg_0x011a_c_ctl_pga_rbb::Cint
    reg_0x011b_resrv_rbb::Cint
    reg_0x011c_reset_n::Cint
    reg_0x011c_spdup_vco::Cint
    reg_0x011c_bypldo_vco::Cint
    reg_0x011c_en_coarsepll::Cint
    reg_0x011c_curlim_vco::Cint
    reg_0x011c_en_div2_divprog::Cint
    reg_0x011c_en_intonly_sdm::Cint
    reg_0x011c_en_sdm_clk::Cint
    reg_0x011c_pd_fbdiv::Cint
    reg_0x011c_pd_loch_t2rbuf::Cint
    reg_0x011c_pd_cp::Cint
    reg_0x011c_pd_fdiv::Cint
    reg_0x011c_pd_sdm::Cint
    reg_0x011c_pd_vco_comp::Cint
    reg_0x011c_pd_vco::Cint
    reg_0x011c_en_g::Cint
    reg_0x011d_frac_sdm::Cint
    reg_0x011e_int_sdm::Cint
    reg_0x011e_frac_sdm::Cint
    reg_0x011f_pw_div2_loch::Cint
    reg_0x011f_pw_div4_loch::Cint
    reg_0x011f_div_loch::Cint
    reg_0x011f_tst_sx::Cint
    reg_0x011f_sel_sdmclk::Cint
    reg_0x011f_sx_dither_en::Cint
    reg_0x011f_rev_sdmclk::Cint
    reg_0x0120_vdiv_vco::Cint
    reg_0x0120_ict_vco::Cint
    reg_0x0121_rsel_ldo_vco::Cint
    reg_0x0121_csw_vco::Cint
    reg_0x0121_sel_vco::Cint
    reg_0x0121_coarse_start::Cint
    reg_0x0122_revph_pfd::Cint
    reg_0x0122_ioffset_cp::Cint
    reg_0x0122_ipulse_cp::Cint
    reg_0x0123_coarse_stepdone::Cint
    reg_0x0123_coarsepll_compo::Cint
    reg_0x0123_vco_cmpho::Cint
    reg_0x0123_vco_cmplo::Cint
    reg_0x0123_cp2_pll::Cint
    reg_0x0123_cp3_pll::Cint
    reg_0x0123_cz::Cint
    reg_0x0124_en_dir_sxx::Cint
    reg_0x0124_en_dir_rbb::Cint
    reg_0x0124_en_dir_rfe::Cint
    reg_0x0124_en_dir_tbb::Cint
    reg_0x0124_en_dir_trf::Cint
    reg_0x0125_value::Cint
    reg_0x0126_value::Cint
    reg_0x0200_tsgfc::Cint
    reg_0x0200_tsgfcw::Cint
    reg_0x0200_tsgdcldq::Cint
    reg_0x0200_tsgdcldi::Cint
    reg_0x0200_tsgswapiq::Cint
    reg_0x0200_tsgmode::Cint
    reg_0x0200_insel::Cint
    reg_0x0200_bstart::Cint
    reg_0x0200_en::Cint
    reg_0x0201_gcorrq::Cint
    reg_0x0202_gcorri::Cint
    reg_0x0203_hbi_ovr::Cint
    reg_0x0203_iqcorr::Cint
    reg_0x0204_dccorri::Cint
    reg_0x0204_dccorrq::Cint
    reg_0x0205_gfir1_l::Cint
    reg_0x0205_gfir1_n::Cint
    reg_0x0206_gfir2_l::Cint
    reg_0x0206_gfir2_n::Cint
    reg_0x0207_gfir3_l::Cint
    reg_0x0207_gfir3_n::Cint
    reg_0x0208_cmix_gain::Cint
    reg_0x0208_cmix_sc::Cint
    reg_0x0208_cmix_byp::Cint
    reg_0x0208_isinc_byp::Cint
    reg_0x0208_gfir3_byp::Cint
    reg_0x0208_gfir2_byp::Cint
    reg_0x0208_gfir1_byp::Cint
    reg_0x0208_dc_byp::Cint
    reg_0x0208_gc_byp::Cint
    reg_0x0208_ph_byp::Cint
    reg_0x0209_value::Cint
    reg_0x020a_value::Cint
    reg_0x020c_dc_reg::Cint
    reg_0x0240_dthbit::Cint
    reg_0x0240_sel::Cint
    reg_0x0240_mode::Cint
    reg_0x0241_pho::Cint
    reg_0x0242_fcw0_hi::Cint
    reg_0x0243_fcw0_lo::Cint
    reg_0x0400_capture::Cint
    reg_0x0400_capsel::Cint
    reg_0x0400_tsgfc::Cint
    reg_0x0400_tsgfcw::Cint
    reg_0x0400_tsgdcldq::Cint
    reg_0x0400_tsgdcldi::Cint
    reg_0x0400_tsgswapiq::Cint
    reg_0x0400_tsgmode::Cint
    reg_0x0400_insel::Cint
    reg_0x0400_bstart::Cint
    reg_0x0400_en::Cint
    reg_0x0401_gcorrq::Cint
    reg_0x0402_gcorri::Cint
    reg_0x0403_hbd_ovr::Cint
    reg_0x0403_iqcorr::Cint
    reg_0x0404_dccorr_avg::Cint
    reg_0x0405_gfir1_l::Cint
    reg_0x0405_gfir1_n::Cint
    reg_0x0406_gfir2_l::Cint
    reg_0x0406_gfir2_n::Cint
    reg_0x0407_gfir3_l::Cint
    reg_0x0407_gfir3_n::Cint
    reg_0x0408_agc_k_lsb::Cint
    reg_0x0409_agc_adesired::Cint
    reg_0x0409_agc_k_msb::Cint
    reg_0x040a_agc_mode::Cint
    reg_0x040a_agc_avg::Cint
    reg_0x040b_dc_reg::Cint
    reg_0x040c_cmix_gain::Cint
    reg_0x040c_cmix_sc::Cint
    reg_0x040c_dc_loop_byp::Cint
    reg_0x040c_cmix_byp::Cint
    reg_0x040c_agc_byp::Cint
    reg_0x040c_gfir3_byp::Cint
    reg_0x040c_gfir2_byp::Cint
    reg_0x040c_gfir1_byp::Cint
    reg_0x040c_dc_byp::Cint
    reg_0x040c_gc_byp::Cint
    reg_0x040c_ph_byp::Cint
    reg_0x040e_value::Cint
    reg_0x0440_dthbit::Cint
    reg_0x0440_sel::Cint
    reg_0x0440_mode::Cint
    reg_0x0441_pho::Cint
    reg_0x0442_fcw0_hi::Cint
    reg_0x0443_fcw0_lo::Cint
    reg_0x05c0_value::Cint
    reg_0x05c1_value::Cint
    reg_0x05c2_value::Cint
    reg_0x05c3_value::Cint
    reg_0x05c4_value::Cint
    reg_0x05c5_value::Cint
    reg_0x05c6_value::Cint
    reg_0x05c7_value::Cint
    reg_0x05c8_value::Cint
    reg_0x05c9_value::Cint
    reg_0x05ca_value::Cint
    reg_0x05cb_value::Cint
    reg_0x05cc_value::Cint
    reg_0x0600_value::Cint
    reg_0x0601_value::Cint
    reg_0x0602_value::Cint
    reg_0x0603_value::Cint
    reg_0x0604_value::Cint
    reg_0x0605_value::Cint
    reg_0x0606_value::Cint
    reg_0x0640_value::Cint
    reg_0x0641_value::Cint
end

const LMS7002M_regs_t = LMS7002M_regs_struct

"""
    LMS7002M_regs_init(regs)

initialize a register structure with default values
"""
function LMS7002M_regs_init(regs)
    ccall((:LMS7002M_regs_init, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_regs_t},), regs)
end

"""
    LMS7002M_regs_set(regs, addr, value)

set the fields from the value that belong to the register specified by addr
"""
function LMS7002M_regs_set(regs, addr, value)
    ccall((:LMS7002M_regs_set, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_regs_t}, Cint, Cint), regs, addr, value)
end

"""
    LMS7002M_regs_default(addr)

get the reset or default value of register specified by its address
"""
function LMS7002M_regs_default(addr)
    ccall((:LMS7002M_regs_default, libSoapyXTRX), Cint, (Cint,), addr)
end

"""
    LMS7002M_regs_get(regs, addr)

get the value of the register specified by the fields at the given address
"""
function LMS7002M_regs_get(regs, addr)
    ccall((:LMS7002M_regs_get, libSoapyXTRX), Cint, (Ptr{LMS7002M_regs_t}, Cint), regs, addr)
end

function LMS7002M_regs_addrs()
    ccall((:LMS7002M_regs_addrs, libSoapyXTRX), Ptr{Cint}, ())
end

"""
    LMS7002M_dir_t

direction constants
"""
@cenum LMS7002M_dir_t::UInt32 begin
    LMS_TX = 1
    LMS_RX = 2
end

"""
    LMS7002M_chan_t

channel constants
"""
@cenum LMS7002M_chan_t::UInt32 begin
    LMS_CHA = 65
    LMS_CHB = 66
    LMS_CHAB = 67
end

"""
    LMS7002M_port_t

port number constants
"""
@cenum LMS7002M_port_t::UInt32 begin
    LMS_PORT1 = 1
    LMS_PORT2 = 2
end

# typedef uint32_t ( * LMS7002M_spi_transact_t ) ( void * handle , const uint32_t data , const bool readback )
"""
Function typedef for a function that implements SPI register transactions.
The handle is the same pointer that the handle passed into the driver instance.
Example: the data may be a pointer to a /dev/spiXX file descriptor

The readback option supplied by the driver specifies whether or not
it requires the result of the spi transaction to be returned.
The implementor of this function can use the readback parameter
to implement non-blocking spi transactions (as an optimization).

\\param handle handle provided data
\\param data the 32-bit write data
\\param readback true to readback
\\return the 32-bit readback data
"""
const LMS7002M_spi_transact_t = Ptr{Cvoid}

"""
The opaque instance of the LMS7002M instance
"""
mutable struct LMS7002M_struct end

"""
Helpful typedef for the LMS7002M driver instance
"""
const LMS7002M_t = LMS7002M_struct

"""
    LMS7002M_create(transact, handle)

Create an instance of the LMS7002M driver.
This call does not reset or initialize the LMS7002M.
See LMS7002M_init(...) and LMS7002M_reset(...).

\\param transact the SPI transaction function
\\param handle arbitrary handle data for transact
\\return a new instance of the LMS7002M driver
"""
function LMS7002M_create(transact, handle)
    ccall((:LMS7002M_create, libSoapyXTRX), Ptr{LMS7002M_t}, (LMS7002M_spi_transact_t, Ptr{Cvoid}), transact, handle)
end

"""
    LMS7002M_destroy(self)

Destroy an instance of the LMS7002M driver.
This call simply fees the instance data,
it does not shutdown or have any effects on the chip.
Use the LMS7002M_power_down(...) call before destroy().

\\param self an instance of the LMS7002M driver
"""
function LMS7002M_destroy(self)
    ccall((:LMS7002M_destroy, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_spi_write(self, addr, value)

Perform a SPI write transaction on the given device.
This call can be used directly to access SPI registers,
rather than indirectly through the high level driver calls.
\\param self an instance of the LMS7002M driver
\\param addr the 16 bit register address
\\param value the 16 bit register value
"""
function LMS7002M_spi_write(self, addr, value)
    ccall((:LMS7002M_spi_write, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint, Cint), self, addr, value)
end

"""
    LMS7002M_spi_read(self, addr)

Perform a SPI read transaction on the given device.
This call can be used directly to access SPI registers,
rather than indirectly through the high level driver calls.
\\param self an instance of the LMS7002M driver
\\param addr the 16 bit register address
\\return the 16 bit register value
"""
function LMS7002M_spi_read(self, addr)
    ccall((:LMS7002M_spi_read, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, Cint), self, addr)
end

"""
    LMS7002M_regs_spi_write(self, addr)

Write a spi register using values from the regs structure.
\\param self an instance of the LMS7002M driver
\\param addr the 16 bit register address
"""
function LMS7002M_regs_spi_write(self, addr)
    ccall((:LMS7002M_regs_spi_write, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint), self, addr)
end

"""
    LMS7002M_regs_spi_read(self, addr)

Read a spi register, filling in the fields in the regs structure.
\\param self an instance of the LMS7002M driver
\\param addr the 16 bit register address
"""
function LMS7002M_regs_spi_read(self, addr)
    ccall((:LMS7002M_regs_spi_read, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint), self, addr)
end

"""
    LMS7002M_regs(self)

Get access to the registers structure and unpacked fields.
Use LMS7002M_regs_spi_write()/LMS7002M_regs_spi_read()
to sync the fields in this structure with the device.
\\param self an instance of the LMS7002M driver
\\return the pointer to the unpacked LMS7002M fields
"""
function LMS7002M_regs(self)
    ccall((:LMS7002M_regs, libSoapyXTRX), Ptr{LMS7002M_regs_t}, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_regs_to_rfic(self)

Write the entire internal register cache to the RFIC.
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_regs_to_rfic(self)
    ccall((:LMS7002M_regs_to_rfic, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_rfic_to_regs(self)

Read the the entire RFIC into the internal register cache.
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_rfic_to_regs(self)
    ccall((:LMS7002M_rfic_to_regs, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_dump_ini(self, path)

Dump the known registers to an INI format like the one used by the EVB7 GUI.
\\param self an instance of the LMS7002M driver
\\param path the path to a .ini output file
\\return 0 for success otherwise failure
"""
function LMS7002M_dump_ini(self, path)
    ccall((:LMS7002M_dump_ini, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, Ptr{Cchar}), self, path)
end

"""
    LMS7002M_load_ini(self, path)

Load registers from an INI format like the one used by the EVB7 GUI.
\\param self an instance of the LMS7002M driver
\\param path the path to a .ini input file
\\return 0 for success otherwise failure
"""
function LMS7002M_load_ini(self, path)
    ccall((:LMS7002M_load_ini, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, Ptr{Cchar}), self, path)
end

"""
    LMS7002M_set_spi_mode(self, numWires)

Set the SPI mode (4-wire or 3-wire).
We recommend that you set this before any additional communication.
\\param self an instance of the LMS7002M driver
\\param numWires the number 3 or the number 4
"""
function LMS7002M_set_spi_mode(self, numWires)
    ccall((:LMS7002M_set_spi_mode, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint), self, numWires)
end

"""
    LMS7002M_reset(self)

Perform all soft and hard resets available.
Call this first to put the LMS7002M into a known state.
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_reset(self)
    ccall((:LMS7002M_reset, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_reset_lml_fifo(self, direction)

Reset all logic registers and FIFO state.
Use after configuring and before streaming.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
"""
function LMS7002M_reset_lml_fifo(self, direction)
    ccall((:LMS7002M_reset_lml_fifo, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t), self, direction)
end

"""
    LMS7002M_power_down(self)

Put all available hardware into disable/power-down mode.
Call this last before destroying the LMS7002M instance.
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_power_down(self)
    ccall((:LMS7002M_power_down, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_configure_lml_port(self, portNo, direction, mclkDiv)

Configure the muxing and clocking on a lime light port.
This sets the data mode and direction for the DIQ pins,
and selects the appropriate clock and stream muxes.
This call is not compatible with JESD207 operation.

The mclkDiv must be 1 for no divider, or an even value.
Odd divider values besides 1 (bypass) are not allowed.

\\param self an instance of the LMS7002M driver
\\param portNo the lime light data port 1 or 2
\\param direction the direction LMS_TX or LMS_RX
\\param mclkDiv the output clock divider ratio
"""
function LMS7002M_configure_lml_port(self, portNo, direction, mclkDiv)
    ccall((:LMS7002M_configure_lml_port, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_port_t, LMS7002M_dir_t, Cint), self, portNo, direction, mclkDiv)
end

"""
    LMS7002M_invert_fclk(self, invert)

Invert the feedback clock used with the transmit pins.
This call inverts both FCLK1 and FCLK2 (only one of which is used).
\\param self an instance of the LMS7002M driver
\\param invert true to invert the clock
"""
function LMS7002M_invert_fclk(self, invert)
    ccall((:LMS7002M_invert_fclk, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool), self, invert)
end

"""
    LMS7002M_delay_fclk(self, delay)

Delays the feedback clock used with the transmit pins.
This call Delays both FCLK1 and FCLK2 (only one of which is used).
\\param self an instance of the LMS7002M driver
\\param delay how much to delay the clock (0-3)
"""
function LMS7002M_delay_fclk(self, delay)
    ccall((:LMS7002M_delay_fclk, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint), self, delay)
end

"""
    LMS7002M_invert_mclk(self, invert)

Invert the output clock used with the transmit pins.
This call inverts both MCLK1 and MCLK2 (only one of which is used).
\\param self an instance of the LMS7002M driver
\\param invert true to invert the clock
"""
function LMS7002M_invert_mclk(self, invert)
    ccall((:LMS7002M_invert_mclk, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool), self, invert)
end

"""
    LMS7002M_delay_mclk(self, delay)

Delays the output clock used with the transmit pins.
This call Delays both MCLK1 and MCLK2 (only one of which is used).
\\param self an instance of the LMS7002M driver
\\param delay how much to delay the clock (0-3)
"""
function LMS7002M_delay_mclk(self, delay)
    ccall((:LMS7002M_delay_mclk, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Cint), self, delay)
end

"""
    LMS7002M_setup_digital_loopback(self)

Enable digital loopback inside the lime light.
This call also applies the tx fifo write clock to the rx fifo.
To undo the effect of this loopback, call LMS7002M_configure_lml_port().
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_setup_digital_loopback(self)
    ccall((:LMS7002M_setup_digital_loopback, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_setup_digital_loopback_lfsr(self)

Enable digital loopback inside the lime light using LFSR data.
This call also applies the tx fifo write clock to the rx fifo.
To undo the effect of this loopback, call LMS7002M_configure_lml_port().
\\param self an instance of the LMS7002M driver
"""
function LMS7002M_setup_digital_loopback_lfsr(self)
    ccall((:LMS7002M_setup_digital_loopback_lfsr, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_set_mac_ch(self, channel)

Set the MAC mux for channel A/B shadow registers.
This call does not incur a register write if the value is unchanged.
This call is mostly used internally by other calls that have to set the MAC.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_set_mac_ch(self, channel)
    ccall((:LMS7002M_set_mac_ch, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_set_mac_dir(self, direction)

Set the MAC mux for direction TX/RX shadow registers.
For SXT and SXR, MAX is used for direction and not channel control.
This call does not incur a register write if the value is unchanged.
This call is mostly used internally by other calls that have to set the MAC.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
"""
function LMS7002M_set_mac_dir(self, direction)
    ccall((:LMS7002M_set_mac_dir, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t), self, direction)
end

"""
    LMS7002M_set_diq_mux(self, direction, positions)

Set the DIQ mux to control CHA and CHB I and Q ordering.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param positions sample position 0-3 (see LMS7002M_LML_*)
"""
function LMS7002M_set_diq_mux(self, direction, positions)
    ccall((:LMS7002M_set_diq_mux, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t, Ptr{Cint}), self, direction, positions)
end

"""
    LMS7002M_ldo_enable(self, enable, group)

Enable/disable a group of LDOs.
\\param self an instance of the LMS7002M driver
\\param enable true to enable, false to power down
\\param group a group of LDOs see LMS7002M_LDO_*
"""
function LMS7002M_ldo_enable(self, enable, group)
    ccall((:LMS7002M_ldo_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool, Cint), self, enable, group)
end

"""
    LMS7002M_xbuf_share_tx(self, enable)

Share the TX XBUF clock chain to the RX XBUF clock chain.
Enabled sharing when there is no clock provided to the RX input.
\\param self an instance of the LMS7002M driver
\\param enable true to enable sharing, false to use separate inputs
"""
function LMS7002M_xbuf_share_tx(self, enable)
    ccall((:LMS7002M_xbuf_share_tx, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool), self, enable)
end

"""
    LMS7002M_xbuf_enable_bias(self, enable)

Enable input biasing the DC voltage level for clock inputs.
When disabled, the input clocks should be DC coupled.
\\param self an instance of the LMS7002M driver
\\param enable true to enable input bias, false to disable
"""
function LMS7002M_xbuf_enable_bias(self, enable)
    ccall((:LMS7002M_xbuf_enable_bias, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool), self, enable)
end

"""
    LMS7002M_afe_enable(self, direction, channel, enable)

Enable/disable individual DACs and ADCs in the AFE section.
Use the direction and channel parameters to specify a DAC/DAC.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to power down
"""
function LMS7002M_afe_enable(self, direction, channel, enable)
    ccall((:LMS7002M_afe_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t, LMS7002M_chan_t, Bool), self, direction, channel, enable)
end

"""
    LMS7002M_set_data_clock(self, fref, fout, factual)

Configure the ADC/DAC clocking given the reference and the desired rate.
This is a helper function that may make certain non-ideal assumptions,
for example this calculation will always make use of fractional-N tuning.
Also, this function does not directly set the clock muxing (see CGEN section).
\\param self an instance of the LMS7002M driver
\\param fref the reference clock frequency in Hz
\\param fout the desired data clock frequency in Hz
\\param factual the actual clock rate in Hz (or NULL)
\\return 0 for success or error code on failure
"""
function LMS7002M_set_data_clock(self, fref, fout, factual)
    ccall((:LMS7002M_set_data_clock, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, Cdouble, Cdouble, Ptr{Cdouble}), self, fref, fout, factual)
end

"""
    LMS7002M_set_nco_freq(self, direction, channel, freqRel)

Set the frequency for the specified NCO.
Most users should use LMS7002M_xxtsp_set_freq() to handle bypasses.
Note: there is a size 16 table for every NCO, we are just using entry 0.
Math: freqHz = freqRel * sampleRate
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param channel the channel LMS_CHA or LMS_CHB
\\param freqRel a fractional frequency in (-0.5, 0.5)
"""
function LMS7002M_set_nco_freq(self, direction, channel, freqRel)
    ccall((:LMS7002M_set_nco_freq, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t, LMS7002M_chan_t, Cdouble), self, direction, channel, freqRel)
end

"""
    LMS7002M_set_gfir_taps(self, direction, channel, which, taps, ntaps)

Set the filter taps for one of the TSP FIR filters.

If the taps array is NULL or the ntaps is 0,
then the specified filter will be bypassed,
otherwise, the specified filter is enabled.

An error will be returned when the taps size is incorrect,
or if a non-existent filter is selected (use 1, 2, or 3).
Filters 1 and 2 are 40 taps, while filter 3 is 120 taps.

\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param channel the channel LMS_CHA or LMS_CHB
\\param which which FIR filter 1, 2, or 3
\\param taps a pointer to an array of taps
\\param ntaps the size of the taps array
\\return 0 for success or error code on failure
"""
function LMS7002M_set_gfir_taps(self, direction, channel, which, taps, ntaps)
    ccall((:LMS7002M_set_gfir_taps, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_dir_t, LMS7002M_chan_t, Cint, Ptr{Cshort}, Csize_t), self, direction, channel, which, taps, ntaps)
end

"""
    LMS7002M_sxx_enable(self, direction, enable)

Enable/disable the synthesizer.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param enable true to enable, false to power down
"""
function LMS7002M_sxx_enable(self, direction, enable)
    ccall((:LMS7002M_sxx_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_dir_t, Bool), self, direction, enable)
end

"""
    LMS7002M_set_lo_freq(self, direction, fref, fout, factual)

The simplified tuning algorithm for the RX and TX local oscillators.
Each oscillator is shared between both channels A and B.
This is a helper function that may make certain non-ideal assumptions,
for example this calculation will always make use of fractional-N tuning.
\\param self an instance of the LMS7002M driver
\\param direction the direction LMS_TX or LMS_RX
\\param fref the reference clock frequency in Hz
\\param fout the desired LO frequency in Hz
\\param factual the actual LO frequency in Hz (or NULL)
\\return 0 for success or error code on failure
"""
function LMS7002M_set_lo_freq(self, direction, fref, fout, factual)
    ccall((:LMS7002M_set_lo_freq, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_dir_t, Cdouble, Cdouble, Ptr{Cdouble}), self, direction, fref, fout, factual)
end

"""
    LMS7002M_sxt_to_sxr(self, enable)

Share the transmit LO to the receive chain.
This is useful for TDD modes which use the same LO for Rx and Tx.
The default is disabled. Its recommended to disable SXR when using.
\\param self an instance of the LMS7002M driver
\\param enable true to enable, false to power down
"""
function LMS7002M_sxt_to_sxr(self, enable)
    ccall((:LMS7002M_sxt_to_sxr, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, Bool), self, enable)
end

"""
    LMS7002M_txtsp_enable(self, channel, enable)

Initialize the TX TSP chain by:
Clearing configuration values, enabling the chain,
and bypassing IQ gain, phase, DC corrections, and filters.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to disable
"""
function LMS7002M_txtsp_enable(self, channel, enable)
    ccall((:LMS7002M_txtsp_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_txtsp_set_interp(self, channel, interp)

Set the TX TSP chain interpolation.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param interp the interpolation 1, 2, 4, 8, 16, 32
"""
function LMS7002M_txtsp_set_interp(self, channel, interp)
    ccall((:LMS7002M_txtsp_set_interp, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Csize_t), self, channel, interp)
end

"""
    LMS7002M_txtsp_set_freq(self, channel, freqRel)

Set the TX TSP CMIX frequency.
Math: freqHz = TSPRate * sampleRate
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param freqRel a fractional frequency in (-0.5, 0.5)
"""
function LMS7002M_txtsp_set_freq(self, channel, freqRel)
    ccall((:LMS7002M_txtsp_set_freq, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, freqRel)
end

"""
    LMS7002M_txtsp_tsg_const(self, channel, valI, valQ)

Test constant signal level for TX TSP chain.
Use LMS7002M_txtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param valI the I constant value
\\param valQ the Q constant value
"""
function LMS7002M_txtsp_tsg_const(self, channel, valI, valQ)
    ccall((:LMS7002M_txtsp_tsg_const, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint, Cint), self, channel, valI, valQ)
end

"""
    LMS7002M_txtsp_tsg_tone(self, channel)

Test tone signal for TX TSP chain (TSP clk/8).
Use LMS7002M_txtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_txtsp_tsg_tone(self, channel)
    ccall((:LMS7002M_txtsp_tsg_tone, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_txtsp_tsg_tone_div(self, channel, div)

Test tone signal for TX TSP chain with selectable divider.
Use LMS7002M_txtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_txtsp_tsg_tone_div(self, channel, div)
    ccall((:LMS7002M_txtsp_tsg_tone_div, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, div)
end

"""
    LMS7002M_txtsp_set_dc_correction(self, channel, valI, valQ)

DC offset correction value for Tx TSP chain.
Correction values are maximum 1.0 (full scale).
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param valI the I correction value
\\param valQ the Q correction value
"""
function LMS7002M_txtsp_set_dc_correction(self, channel, valI, valQ)
    ccall((:LMS7002M_txtsp_set_dc_correction, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble, Cdouble), self, channel, valI, valQ)
end

"""
    LMS7002M_txtsp_set_iq_correction(self, channel, phase, gain)

IQ imbalance correction value for Tx TSP chain.

- The gain is the ratio of I/Q, and should be near 1.0
- Gain values greater than 1.0 max out I and reduce Q.
- Gain values less than 1.0 max out Q and reduce I.
- A gain value of 1.0 bypasses the magnitude correction.
- A phase value of 0.0 bypasses the phase correction.

\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param phase the phase correction (radians)
\\param gain the magnitude correction (I/Q ratio)
"""
function LMS7002M_txtsp_set_iq_correction(self, channel, phase, gain)
    ccall((:LMS7002M_txtsp_set_iq_correction, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble, Cdouble), self, channel, phase, gain)
end

"""
    LMS7002M_tbb_enable(self, channel, enable)

Enable/disable the TX baseband.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to power down
"""
function LMS7002M_tbb_enable(self, channel, enable)
    ccall((:LMS7002M_tbb_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_tbb_set_path(self, channel, path)

Select the data path for the TX baseband.
Use this to select loopback and filter paths.
Calling LMS7002M_tbb_set_filter_bw() will also
set the path based on the filter bandwidth setting.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param path the input path (see LMS7002M_TBB_* defines)
"""
function LMS7002M_tbb_set_path(self, channel, path)
    ccall((:LMS7002M_tbb_set_path, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, path)
end

"""
    LMS7002M_tbb_get_path(self, channel)

Get the data path for the TX baseband.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_tbb_get_path(self, channel)
    ccall((:LMS7002M_tbb_get_path, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_tbb_set_test_in(self, channel, path)

Configure the test input signal to the TX BB component.
The default is disabled (LMS7002M_TBB_TSTIN_OFF).
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param path the input path (see LMS7002M_TBB_TSTIN_* defines)
"""
function LMS7002M_tbb_set_test_in(self, channel, path)
    ccall((:LMS7002M_tbb_set_test_in, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, path)
end

"""
    LMS7002M_tbb_enable_loopback(self, channel, mode, swap)

Enable/disable the TX BB loopback to RBB.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param mode loopback mode (see LMS7002M_TBB_LB_* defines)
\\param swap true to swap I and Q in the loopback
"""
function LMS7002M_tbb_enable_loopback(self, channel, mode, swap)
    ccall((:LMS7002M_tbb_enable_loopback, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint, Bool), self, channel, mode, swap)
end

"""
    LMS7002M_tbb_set_filter_bw(self, channel, bw, bwactual)

Set the TX baseband filter bandwidth.
The actual bandwidth will be greater than or equal to the requested bandwidth.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param bw the complex bandwidth in Hz
\\param bwactual the actual filter width in Hz or NULL
\\return 0 for success or error code on failure
"""
function LMS7002M_tbb_set_filter_bw(self, channel, bw, bwactual)
    ccall((:LMS7002M_tbb_set_filter_bw, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble, Ptr{Cdouble}), self, channel, bw, bwactual)
end

"""
    LMS7002M_trf_enable(self, channel, enable)

Enable/disable the TX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to power down
"""
function LMS7002M_trf_enable(self, channel, enable)
    ccall((:LMS7002M_trf_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_trf_select_band(self, channel, band)

Select the TX RF band (band 1 or band 2)
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param band the band number, values 1 or 2
"""
function LMS7002M_trf_select_band(self, channel, band)
    ccall((:LMS7002M_trf_select_band, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, band)
end

"""
    LMS7002M_trf_enable_loopback(self, channel, enable)

Enable/disable the TX RF loopback to RFE.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable the loopback
"""
function LMS7002M_trf_enable_loopback(self, channel, enable)
    ccall((:LMS7002M_trf_enable_loopback, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_trf_set_pad(self, channel, gain)

Set the PAD gain (loss) for the TX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB -52.0 to 0.0
\\return the actual gain value in dB
"""
function LMS7002M_trf_set_pad(self, channel, gain)
    ccall((:LMS7002M_trf_set_pad, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_trf_set_loopback_pad(self, channel, gain)

Set the PAD gain (loss) for the TX RF frontend (in RX loopback mode).
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB -24.0 to 0.0
\\return the actual gain value in dB
"""
function LMS7002M_trf_set_loopback_pad(self, channel, gain)
    ccall((:LMS7002M_trf_set_loopback_pad, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_rxtsp_enable(self, channel, enable)

Initialize the RX TSP chain by:
Clearing configuration values, enabling the chain,
and bypassing IQ gain, phase, DC corrections, filters, and AGC.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to disable
"""
function LMS7002M_rxtsp_enable(self, channel, enable)
    ccall((:LMS7002M_rxtsp_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_rxtsp_set_decim(self, channel, decim)

Set the RX TSP chain decimation.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param decim the decimation 1, 2, 4, 8, 16, 32
"""
function LMS7002M_rxtsp_set_decim(self, channel, decim)
    ccall((:LMS7002M_rxtsp_set_decim, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Csize_t), self, channel, decim)
end

"""
    LMS7002M_rxtsp_set_freq(self, channel, freqRel)

Set the RX TSP CMIX frequency.
Math: freqHz = TSPRate * sampleRate
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param freqRel a fractional frequency in (-0.5, 0.5)
"""
function LMS7002M_rxtsp_set_freq(self, channel, freqRel)
    ccall((:LMS7002M_rxtsp_set_freq, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, freqRel)
end

"""
    LMS7002M_rxtsp_tsg_const(self, channel, valI, valQ)

Test constant signal level for RX TSP chain.
Use LMS7002M_rxtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param valI the I constant value
\\param valQ the Q constant value
"""
function LMS7002M_rxtsp_tsg_const(self, channel, valI, valQ)
    ccall((:LMS7002M_rxtsp_tsg_const, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint, Cint), self, channel, valI, valQ)
end

"""
    LMS7002M_rxtsp_tsg_tone(self, channel)

Test tone signal for RX TSP chain (TSP clk/8).
Use LMS7002M_rxtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_rxtsp_tsg_tone(self, channel)
    ccall((:LMS7002M_rxtsp_tsg_tone, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_rxtsp_tsg_tone_div(self, channel, div)

Test tone signal for RX TSP chain with selectable clock divider.
Use LMS7002M_rxtsp_enable() to restore regular mode.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_rxtsp_tsg_tone_div(self, channel, div)
    ccall((:LMS7002M_rxtsp_tsg_tone_div, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, div)
end

"""
    LMS7002M_rxtsp_read_rssi(self, channel)

Read the digital RSSI indicator in the Rx TSP chain.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\return the RSSI as an unsigned 16-bit number
"""
function LMS7002M_rxtsp_read_rssi(self, channel)
    ccall((:LMS7002M_rxtsp_read_rssi, libSoapyXTRX), UInt16, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_rxtsp_set_dc_correction(self, channel, enabled, window)

DC offset correction value for Rx TSP chain.
This subtracts out the average signal level.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enabled true to enable correction
\\param window average window length 0-7 (def 0)
"""
function LMS7002M_rxtsp_set_dc_correction(self, channel, enabled, window)
    ccall((:LMS7002M_rxtsp_set_dc_correction, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool, Cint), self, channel, enabled, window)
end

"""
    LMS7002M_rxtsp_set_iq_correction(self, channel, phase, gain)

IQ imbalance correction value for Rx TSP chain.

- The gain is the ratio of I/Q, and should be near 1.0
- Gain values greater than 1.0 max out I and reduce Q.
- Gain values less than 1.0 max out Q and reduce I.
- A gain value of 1.0 bypasses the magnitude correction.
- A phase value of 0.0 bypasses the phase correction.

\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param phase the phase correction (radians)
\\param gain the magnitude correction (I/Q ratio)
"""
function LMS7002M_rxtsp_set_iq_correction(self, channel, phase, gain)
    ccall((:LMS7002M_rxtsp_set_iq_correction, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble, Cdouble), self, channel, phase, gain)
end

"""
    LMS7002M_rbb_enable(self, channel, enable)

Enable/disable the RX baseband.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to power down
"""
function LMS7002M_rbb_enable(self, channel, enable)
    ccall((:LMS7002M_rbb_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_rbb_set_path(self, channel, path)

Select the data path for the RX baseband.
Use this to select loopback and filter paths.
Calling LMS7002M_rbb_set_filter_bw() will also
set the path based on the filter bandwidth setting.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param path the input path (see LMS7002M_RBB_* defines)
"""
function LMS7002M_rbb_set_path(self, channel, path)
    ccall((:LMS7002M_rbb_set_path, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, path)
end

"""
    LMS7002M_rbb_get_path(self, channel)

Get the current data path for the RX baseband.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
"""
function LMS7002M_rbb_get_path(self, channel)
    ccall((:LMS7002M_rbb_get_path, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t), self, channel)
end

"""
    LMS7002M_rbb_set_test_out(self, channel, enable)

Configure the test output signal from the RX BB component.
The default is false meaning that the RBB outputs to the ADC.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to output RBB to pad, false for ADC
"""
function LMS7002M_rbb_set_test_out(self, channel, enable)
    ccall((:LMS7002M_rbb_set_test_out, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_rbb_set_pga(self, channel, gain)

Set the PGA gain for the RX baseband.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB -12.0 to 19.0
\\return the actual gain value in dB
"""
function LMS7002M_rbb_set_pga(self, channel, gain)
    ccall((:LMS7002M_rbb_set_pga, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_rbb_set_filter_bw(self, channel, bw, bwactual)

Set the RX baseband filter bandwidth.
The actual bandwidth will be greater than or equal to the requested bandwidth.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param bw the complex bandwidth in Hz
\\param bwactual the actual filter width in Hz or NULL
\\return 0 for success or error code on failure
"""
function LMS7002M_rbb_set_filter_bw(self, channel, bw, bwactual)
    ccall((:LMS7002M_rbb_set_filter_bw, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble, Ptr{Cdouble}), self, channel, bw, bwactual)
end

"""
    LMS7002M_rfe_enable(self, channel, enable)

Enable/disable the RX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param enable true to enable, false to power down
"""
function LMS7002M_rfe_enable(self, channel, enable)
    ccall((:LMS7002M_rfe_enable, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Bool), self, channel, enable)
end

"""
    LMS7002M_rfe_set_path(self, channel, path)

Select the active input path for the RX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param path the input path (see LMS7002M_RFE_* defines)
"""
function LMS7002M_rfe_set_path(self, channel, path)
    ccall((:LMS7002M_rfe_set_path, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cint), self, channel, path)
end

"""
    LMS7002M_rfe_set_lna(self, channel, gain)

Set the LNA gain for the RX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB 0 to 30
\\return the actual gain value in dB
"""
function LMS7002M_rfe_set_lna(self, channel, gain)
    ccall((:LMS7002M_rfe_set_lna, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_rfe_set_loopback_lna(self, channel, gain)

Set the LNA gain for the RX RF frontend (in TX loopback mode).
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB 0 to 40
\\return the actual gain value in dB
"""
function LMS7002M_rfe_set_loopback_lna(self, channel, gain)
    ccall((:LMS7002M_rfe_set_loopback_lna, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_rfe_set_tia(self, channel, gain)

Set the TIA gain for the RX RF frontend.
\\param self an instance of the LMS7002M driver
\\param channel the channel LMS_CHA or LMS_CHB
\\param gain the gain value in dB 0 to 12
\\return the actual gain value in dB
"""
function LMS7002M_rfe_set_tia(self, channel, gain)
    ccall((:LMS7002M_rfe_set_tia, libSoapyXTRX), Cdouble, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cdouble), self, channel, gain)
end

"""
    LMS7002M_mcu_progmode_t

programming mode constants
"""
@cenum LMS7002M_mcu_progmode_t::UInt32 begin
    MCU_EEPROM_SRAM = 1
    MCU_SRAM = 2
end

"""
    LMS7002M_mcu_param_t

parameter type constants
"""
@cenum LMS7002M_mcu_param_t::UInt32 begin
    MCU_REF_CLK = 0
    MCU_BW = 1
end

"""
    LMS7002M_mcu_write_program(self, mode, program, program_size)

Write a program to the embedded microcontroller.
\\param self an instance of the LMS7002M driver
\\param mode the programming mode indicating what to program
\\param program a pointer to the program
\\param program_size the length of the program in bytes
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_write_program(self, mode, program, program_size)
    ccall((:LMS7002M_mcu_write_program, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_mcu_progmode_t, Ptr{UInt8}, Csize_t), self, mode, program, program_size)
end

"""
    LMS7002M_mcu_run_procedure(self, procedure)

Run a procedure on the embedded microcontroller.
\\param self an instance of the LMS7002M driver
\\param procedure the entry of the procedure in the program table
"""
function LMS7002M_mcu_run_procedure(self, procedure)
    ccall((:LMS7002M_mcu_run_procedure, libSoapyXTRX), Cvoid, (Ptr{LMS7002M_t}, UInt8), self, procedure)
end

"""
    LMS7002M_mcu_wait(self, timeout_ms)

Wait for the microcontroller to finish executing a procedure.
\\param self an instance of the LMS7002M driver
\\param timeout_ms the maximum time to wait in milliseconds
\\return -1 for timeout, and the procedure result otherwise
"""
function LMS7002M_mcu_wait(self, timeout_ms)
    ccall((:LMS7002M_mcu_wait, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, Cuint), self, timeout_ms)
end

"""
    LMS7002M_mcu_set_parameter(self, param, value)

Set a parameter on the embedded microcontroller. This can be used for
procedures that requires inputs, like the calibration program.
\\param self an instance of the LMS7002M driver
\\param param the parameter to write
\\param value the parameter to write
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_set_parameter(self, param, value)
    ccall((:LMS7002M_mcu_set_parameter, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_mcu_param_t, Cfloat), self, param, value)
end

"""
    LMS7002M_mcu_write_calibration_program(self)

Write the LMS7002M calibration program to the embedded microcontroller.
\\param self an instance of the LMS7002M driver
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_write_calibration_program(self)
    ccall((:LMS7002M_mcu_write_calibration_program, libSoapyXTRX), Cint, (Ptr{LMS7002M_t},), self)
end

"""
    LMS7002M_mcu_calibration_rx(self, channel, clk, bw)

Use the embedded microcontroller to calibrate the RX analog filter.
\\param self an instance of the LMS7002M driver
\\param clk the reference clock
\\param self the bandwidth to calibrate for
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_calibration_rx(self, channel, clk, bw)
    ccall((:LMS7002M_mcu_calibration_rx, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cfloat, Cfloat), self, channel, clk, bw)
end

"""
    LMS7002M_mcu_calibration_tx(self, channel, clk, bw)

Use the embedded microcontroller to calibrate the TX analog filter.
\\param self an instance of the LMS7002M driver
\\param clk the reference clock
\\param self the bandwidth to calibrate for
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_calibration_tx(self, channel, clk, bw)
    ccall((:LMS7002M_mcu_calibration_tx, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cfloat, Cfloat), self, channel, clk, bw)
end

"""
LMS7002M_mcu_calibration_dc_offset_iq_imbalance_rx(self, channel, clk, bw)

Use the embedded microcontroller to calibrate the RX DC offsets and IQ imbalance.
\\param self an instance of the LMS7002M driver
\\param clk the reference clock
\\param self the bandwidth to calibrate for
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_calibration_dc_offset_iq_imbalance_rx(self, channel, clk, bw)
    ccall((:LMS7002M_mcu_calibration_dc_offset_iq_imbalance_rx, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cfloat, Cfloat), self, channel, clk, bw)
end

"""
LMS7002M_mcu_calibration_dc_offset_iq_imbalance_tx(self, channel, clk, bw)

Use the embedded microcontroller to calibrate the TX DC offsets and IQ imbalance.
\\param self an instance of the LMS7002M driver
\\param clk the reference clock
\\param self the bandwidth to calibrate for
\\return 0 for success otherwise failure
"""
function LMS7002M_mcu_calibration_dc_offset_iq_imbalance_tx(self, channel, clk, bw)
    ccall((:LMS7002M_mcu_calibration_dc_offset_iq_imbalance_tx, libSoapyXTRX), Cint, (Ptr{LMS7002M_t}, LMS7002M_chan_t, Cfloat, Cfloat), self, channel, clk, bw)
end

const REG_0X0020_MAC_NONE = 0

const REG_0X0020_MAC_CHA = 1

const REG_0X0020_MAC_CHB = 2

const REG_0X0020_MAC_CHAB = 3

const REG_0X0021_SPIMODE_3WIRE = 0

const REG_0X0021_SPIMODE_4WIRE = 1

const REG_0X0022_DIQ2_DS_4MA = 0

const REG_0X0022_DIQ2_DS_8MA = 1

const REG_0X0022_DIQ1_DS_4MA = 0

const REG_0X0022_DIQ1_DS_8MA = 1

const REG_0X0023_DIQDIR2_OUTPUT = 0

const REG_0X0023_DIQDIR2_INPUT = 1

const REG_0X0023_DIQDIR1_OUTPUT = 0

const REG_0X0023_DIQDIR1_INPUT = 1

const REG_0X0023_ENABLEDIR2_OUTPUT = 0

const REG_0X0023_ENABLEDIR2_INPUT = 1

const REG_0X0023_ENABLEDIR1_OUTPUT = 0

const REG_0X0023_ENABLEDIR1_INPUT = 1

const REG_0X0023_LML2_RXNTXIQ_RXIQ = 0

const REG_0X0023_LML2_RXNTXIQ_TXIQ = 1

const REG_0X0023_LML2_MODE_TRXIQ = 0

const REG_0X0023_LML2_MODE_JESD207 = 1

const REG_0X0023_LML1_RXNTXIQ_RXIQ = 0

const REG_0X0023_LML1_RXNTXIQ_TXIQ = 1

const REG_0X0023_LML1_MODE_TRXIQ = 0

const REG_0X0023_LML1_MODE_JESD207 = 1

const REG_0X0024_LML1_S3S_AI = 0

const REG_0X0024_LML1_S3S_AQ = 1

const REG_0X0024_LML1_S3S_BI = 2

const REG_0X0024_LML1_S3S_BQ = 3

const REG_0X0024_LML1_S2S_AI = 0

const REG_0X0024_LML1_S2S_AQ = 1

const REG_0X0024_LML1_S2S_BI = 2

const REG_0X0024_LML1_S2S_BQ = 3

const REG_0X0024_LML1_S1S_AI = 0

const REG_0X0024_LML1_S1S_AQ = 1

const REG_0X0024_LML1_S1S_BI = 2

const REG_0X0024_LML1_S1S_BQ = 3

const REG_0X0024_LML1_S0S_AI = 0

const REG_0X0024_LML1_S0S_AQ = 1

const REG_0X0024_LML1_S0S_BI = 2

const REG_0X0024_LML1_S0S_BQ = 3

const REG_0X0027_LML2_S3S_AI = 0

const REG_0X0027_LML2_S3S_AQ = 1

const REG_0X0027_LML2_S3S_BI = 2

const REG_0X0027_LML2_S3S_BQ = 3

const REG_0X0027_LML2_S2S_AI = 0

const REG_0X0027_LML2_S2S_AQ = 1

const REG_0X0027_LML2_S2S_BI = 2

const REG_0X0027_LML2_S2S_BQ = 3

const REG_0X0027_LML2_S1S_AI = 0

const REG_0X0027_LML2_S1S_AQ = 1

const REG_0X0027_LML2_S1S_BI = 2

const REG_0X0027_LML2_S1S_BQ = 3

const REG_0X0027_LML2_S0S_AI = 0

const REG_0X0027_LML2_S0S_AQ = 1

const REG_0X0027_LML2_S0S_BI = 2

const REG_0X0027_LML2_S0S_BQ = 3

const REG_0X002A_RX_MUX_RXTSP = 0

const REG_0X002A_RX_MUX_TXFIFO = 1

const REG_0X002A_RX_MUX_LFSR = 2

const REG_0X002A_RX_MUX_LFSR_ = 3

const REG_0X002A_TX_MUX_PORT1 = 0

const REG_0X002A_TX_MUX_PORT2 = 1

const REG_0X002A_TX_MUX_RXTSP = 2

const REG_0X002A_TX_MUX_RXTSP_ = 3

const REG_0X002A_TXRDCLK_MUX_FCLK1 = 0

const REG_0X002A_TXRDCLK_MUX_FCLK2 = 1

const REG_0X002A_TXRDCLK_MUX_TXTSPCLK = 2

const REG_0X002A_TXRDCLK_MUX_TXTSPCLK_ = 3

const REG_0X002A_TXWRCLK_MUX_FCLK1 = 0

const REG_0X002A_TXWRCLK_MUX_FCLK2 = 1

const REG_0X002A_TXWRCLK_MUX_RXTSPCLK = 2

const REG_0X002A_TXWRCLK_MUX_RXTSPCLK_ = 3

const REG_0X002A_RXRDCLK_MUX_MCLK1 = 0

const REG_0X002A_RXRDCLK_MUX_MCLK2 = 1

const REG_0X002A_RXRDCLK_MUX_FCLK1 = 2

const REG_0X002A_RXRDCLK_MUX_FCLK2 = 3

const REG_0X002A_RXWRCLK_MUX_FCLK1 = 0

const REG_0X002A_RXWRCLK_MUX_FCLK2 = 1

const REG_0X002A_RXWRCLK_MUX_RXTSPCLK = 2

const REG_0X002A_RXWRCLK_MUX_RXTSPCLK_ = 3

const REG_0X002B_MCLK2SRC_TXTSPCLKA_DIV = 0

const REG_0X002B_MCLK2SRC_RXTSPCLKA_DIV = 1

const REG_0X002B_MCLK2SRC_TXTSPCLKA = 2

const REG_0X002B_MCLK2SRC_RXTSPCLKA = 3

const REG_0X002B_MCLK1SRC_TXTSPCLKA_DIV = 0

const REG_0X002B_MCLK1SRC_RXTSPCLKA_DIV = 1

const REG_0X002B_MCLK1SRC_TXTSPCLKA = 2

const REG_0X002B_MCLK1SRC_RXTSPCLKA = 3

const REG_0X0082_MODE_INTERLEAVE_AFE_2ADCS = 0

const REG_0X0082_MODE_INTERLEAVE_AFE_INTERLEAVED = 1

const REG_0X0082_MUX_AFE_1_MUXOFF = 0

const REG_0X0082_MUX_AFE_1_PDET_1 = 1

const REG_0X0082_MUX_AFE_1_BIAS_TOP = 2

const REG_0X0082_MUX_AFE_1_RSSI1 = 3

const REG_0X0082_MUX_AFE_2_MUXOFF = 0

const REG_0X0082_MUX_AFE_2_PDET_2 = 1

const REG_0X0082_MUX_AFE_2_RSSI1 = 2

const REG_0X0082_MUX_AFE_2_RSSI2 = 3

const REG_0X0089_SEL_SDMCLK_CGEN_CLK_DIV = 0

const REG_0X0089_SEL_SDMCLK_CGEN_CLK_REF = 1

const REG_0X0089_TST_CGEN_DISABLED = 0

const REG_0X0089_TST_CGEN_TSTDO = 1

const REG_0X0089_TST_CGEN_VCO_TUNE_50_KOHM = 2

const REG_0X0089_TST_CGEN_VCO_TUNE = 3

const REG_0X0089_TST_CGEN_PFD_UP = 5

const REG_0X0100_EN_NEXTTX_TRF_SISO = 0

const REG_0X0100_EN_NEXTTX_TRF_MIMO = 1

const REG_0X010D_SEL_PATH_RFE_NONE = 0

const REG_0X010D_SEL_PATH_RFE_LNAH = 1

const REG_0X010D_SEL_PATH_RFE_LNAL = 2

const REG_0X010D_SEL_PATH_RFE_LNAW = 3

const REG_0X010D_EN_NEXTRX_RFE_SISO = 0

const REG_0X010D_EN_NEXTRX_RFE_MIMO = 1

const REG_0X0118_INPUT_CTL_PGA_RBB_LPFL = 0

const REG_0X0118_INPUT_CTL_PGA_RBB_LPFH = 1

const REG_0X0118_INPUT_CTL_PGA_RBB_BYPASS = 2

const REG_0X0118_INPUT_CTL_PGA_RBB_TBB = 3

const REG_0X0118_INPUT_CTL_PGA_RBB_PDET = 4

const REG_0X011F_SEL_SDMCLK_CLK_DIV = 0

const REG_0X011F_SEL_SDMCLK_CLK_REF = 1

const REG_0X0121_SEL_VCO_VCOL = 0

const REG_0X0121_SEL_VCO_VCOM = 1

const REG_0X0121_SEL_VCO_VCOH = 2

const REG_0X0200_TSGFC_NEG6DB = 0

const REG_0X0200_TSGFC_FS = 1

const REG_0X0200_TSGFCW_DIV8 = 1

const REG_0X0200_TSGFCW_DIV4 = 2

const REG_0X0200_TSGMODE_NCO = 0

const REG_0X0200_TSGMODE_DC = 1

const REG_0X0200_INSEL_LML = 0

const REG_0X0200_INSEL_TEST = 1

const REG_0X0203_HBI_OVR_BYPASS = 7

const REG_0X0208_CMIX_GAIN_0DB = 0

const REG_0X0208_CMIX_GAIN_POS6DB = 1

const REG_0X0208_CMIX_GAIN_NEG6DB = 2

const REG_0X0208_CMIX_SC_UPCONVERT = 0

const REG_0X0208_CMIX_SC_DOWNCONVERT = 1

const REG_0X0240_MODE_FCW = 0

const REG_0X0240_MODE_PHO = 1

const REG_0X0400_CAPSEL_RSSI = 0

const REG_0X0400_CAPSEL_ADCI_ADCQ = 1

const REG_0X0400_CAPSEL_BSIGI_BSTATE = 2

const REG_0X0400_CAPSEL_BSIGQ_BSTATE = 3

const REG_0X0400_TSGFC_NEG6DB = 0

const REG_0X0400_TSGFC_FS = 1

const REG_0X0400_TSGFCW_DIV8 = 1

const REG_0X0400_TSGFCW_DIV4 = 2

const REG_0X0400_TSGMODE_NCO = 0

const REG_0X0400_TSGMODE_DC = 1

const REG_0X0400_INSEL_LML = 0

const REG_0X0400_INSEL_TEST = 1

const REG_0X0403_HBD_OVR_BYPASS = 7

const REG_0X040A_AGC_MODE_AGC = 0

const REG_0X040A_AGC_MODE_RSSI = 1

const REG_0X040A_AGC_MODE_BYPASS = 2

const REG_0X040C_CMIX_GAIN_0DB = 0

const REG_0X040C_CMIX_GAIN_POS6DB = 1

const REG_0X040C_CMIX_GAIN_NEG6DB = 2

const REG_0X040C_CMIX_SC_UPCONVERT = 0

const REG_0X040C_CMIX_SC_DOWNCONVERT = 1

const REG_0X0440_MODE_FCW = 0

const REG_0X0440_MODE_PHO = 1

const LMS7002M_CGEN_VCO_LO = 2.0e9

const LMS7002M_CGEN_VCO_HI = 2.7e9

const LMS7002M_SXX_VCOL_LO = 3.8e9

const LMS7002M_SXX_VCOL_HI = 5.222e9

const LMS7002M_SXX_VCOM_LO = 4.961e9

const LMS7002M_SXX_VCOM_HI = 6.754e9

const LMS7002M_SXX_VCOH_LO = 6.306e9

const LMS7002M_SXX_VCOH_HI = 7.714e9

const LMS7002M_LML_AI = 0

const LMS7002M_LML_AQ = 1

const LMS7002M_LML_BI = 2

const LMS7002M_LML_BQ = 3

const LMS7002M_LDO_ALL = 0

const LMS7002M_TBB_BYP = Cint(Cchar('B'))

const LMS7002M_TBB_S5 = Cint(Cchar('S'))

const LMS7002M_TBB_LAD = Cint(Cchar('A'))

const LMS7002M_TBB_LBF = Cint(Cchar('L'))

const LMS7002M_TBB_HBF = Cint(Cchar('H'))

const LMS7002M_TBB_TSTIN_OFF = 0

const LMS7002M_TBB_TSTIN_LBF = 1

const LMS7002M_TBB_TSTIN_HBF = 2

const LMS7002M_TBB_TSTIN_AMP = 3

const LMS7002M_TBB_LB_DISCONNECTED = 0

const LMS7002M_TBB_LB_DAC_CURRENT = 1

const LMS7002M_TBB_LB_LB_LADDER = 2

const LMS7002M_TBB_LB_MAIN_TBB = 3

const LMS7002M_RBB_BYP = Cint(Cchar('B'))

const LMS7002M_RBB_LBF = Cint(Cchar('L'))

const LMS7002M_RBB_HBF = Cint(Cchar('H'))

const LMS7002M_RBB_LB_BYP = 0

const LMS7002M_RBB_LB_LBF = 1

const LMS7002M_RBB_LB_HBF = 2

const LMS7002M_RBB_PDET = 3

const LMS7002M_RFE_NONE = Cint(Cchar('N'))

const LMS7002M_RFE_LNAH = Cint(Cchar('H'))

const LMS7002M_RFE_LNAL = Cint(Cchar('L'))

const LMS7002M_RFE_LNAW = Cint(Cchar('W'))

const LMS7002M_RFE_LB1 = Cint(Cchar('1'))

const LMS7002M_RFE_LB2 = Cint(Cchar('2'))

