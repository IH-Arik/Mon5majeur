'use client';

import AccountingSettings from '@/components/modules/dashboard/settings/AccountingSettings';
import LegalNotice from '@/components/modules/dashboard/settings/LegalNotice';
import ResetPassword from '@/components/modules/dashboard/settings/ResetPassword';
import SupportCenter from '@/components/modules/dashboard/settings/SupportCenter';
import TermsAndConditions from '@/components/modules/dashboard/settings/TermsAndConditions';
import React, { useState } from 'react';

export default function SettingsTabs() {
  const [activeTab, setActiveTab] = useState<
    'accounting' | 'password' | 'legal' | 'terms' | 'support'
  >('accounting');

  return (
    <div>
        <h1 className='text-[32px] mb-10 font-bold'>Settings</h1>
      {/* Responsive Tab Buttons Grid */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4 mb-6">
        <button
          onClick={() => setActiveTab('accounting')}
          className={`px-4 py-2 rounded w-full text-center ${
            activeTab === 'accounting'
              ? 'bg-[#E8632C] text-white'
              : 'bg-gray-200 text-gray-700'
          }`}
        >
          Accounting Settings
        </button>

        <button
          onClick={() => setActiveTab('password')}
          className={`px-4 py-2 rounded w-full text-center ${
            activeTab === 'password'
              ? 'bg-[#E8632C] text-white'
              : 'bg-gray-200 text-gray-700'
          }`}
        >
          Reset Password
        </button>

        <button
          onClick={() => setActiveTab('legal')}
          className={`px-4 py-2 rounded w-full text-center ${
            activeTab === 'legal'
              ? 'bg-[#E8632C] text-white'
              : 'bg-gray-200 text-gray-700'
          }`}
        >
          Legal Notice
        </button>

        <button
          onClick={() => setActiveTab('terms')}
          className={`px-4 py-2 rounded w-full text-center ${
            activeTab === 'terms'
              ? 'bg-[#E8632C] text-white'
              : 'bg-gray-200 text-gray-700'
          }`}
        >
          Terms & Conditions
        </button>

        <button
          onClick={() => setActiveTab('support')}
          className={`px-4 py-2 rounded w-full text-center ${
            activeTab === 'support'
              ? 'bg-[#E8632C] text-white'
              : 'bg-gray-200 text-gray-700'
          }`}
        >
          Support Center
        </button>
      </div>

      {/* Tab Content */}
      <div className="">
        {activeTab === 'accounting' && <AccountingSettings />}
        {activeTab === 'password' && <ResetPassword />}
        {activeTab === 'legal' && <LegalNotice />}
        {activeTab === 'terms' && <TermsAndConditions />}
        {activeTab === 'support' && <SupportCenter />}
      </div>
    </div>
  );
}
