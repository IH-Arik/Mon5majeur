import MatchManagement from '@/components/modules/dashboard/MatchManagement'
import React from 'react'

export default function page() {
  return (
    <div>
      <h2 className='text-[24px] md:text-[28px] lg:text-[30px] font-semibold'>Match Verification Queue</h2>
      <p className='text-[14px] md:text-[16px]'>Matches awaiting score verification or dispute resolution.</p>
      <MatchManagement></MatchManagement>
    </div>
  )
}
